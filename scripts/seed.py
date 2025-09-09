"""
Script Seeding Database 
"""

import sys
import os
import random
import hashlib
import psycopg2
from faker import Faker
from datetime import datetime, timedelta

from config import DATABASE_CONFIG, SEEDING_CONFIG

class DatabaseSeeder:
    def __init__(self):
        self.fake = Faker()
        self.connection = None
        self.cursor = None
        
        self.users = []
        self.coaches = []
        self.fields = []
        self.coach_availabilities = []
        self.field_bookings = []
        self.group_courses = []
        self.payments = []
        self.group_course_orders = []
        self.private_course_orders = []
        self.vouchers = []
    
    def connect_database(self):
        """Membuat koneksi ke database"""
        try:
            self.connection = psycopg2.connect(**DATABASE_CONFIG)
            self.cursor = self.connection.cursor()
            print("\nBerhasil terhubung ke database PostgreSQL")
        except Exception as e:
            print(f"\nGagal terhubung ke database: {e}")
            raise
    
    def close_connection(self):
        """Menutup koneksi database"""
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()
        print("Koneksi database ditutup\n")
    
    def hash_password(self, password):
        """Generate hash password"""
        return hashlib.sha256(password.encode()).hexdigest()
    
    def generate_email_from_name(self, full_name):
        """Generate email dari nama lengkap dalam format: namatanpaspasi@email.com"""
        clean_name = full_name.replace(" ", "").lower()
        
        random_suffix = random.randint(1, 999)
        return f"{clean_name}{random_suffix}@email.com"
    
    def generate_indonesian_phone(self):
        """Generate nomor telepon Indonesia dalam format: +62xxxxxxxxxx"""
        digits = ''.join([str(random.randint(0, 9)) for _ in range(11)])
        return f"+62{digits}"
    
    def clear_all_data(self):
        """Menghapus semua data yang ada dari tabel database"""
        print("Menghapus semua data yang ada dari database...")
        
        tables_to_clear = [
            'vouchers',
            'privatecourseorderdetail',
            'privatecourseorder', 
            'groupcourseorderdetail',
            'groupcourseorder',
            'payments',
            'groupcourses',
            'fieldbookingdetail',
            'coachavailability',
            'coaches',
            'fields',
            'users'
        ]
        
        try:
            self.cursor.execute("SET session_replication_role = replica;")
            
            for table in tables_to_clear:
                self.cursor.execute(f"TRUNCATE TABLE {table} RESTART IDENTITY CASCADE;")
            
            self.cursor.execute("SET session_replication_role = DEFAULT;")
            
            self.connection.commit()
            print("Semua tabel database berhasil dikosongkan!")
            
        except Exception as e:
            print(f"Gagal menghapus data database: {e}")
            self.connection.rollback()
            raise
    
    def seed_users(self):
        """Seeding tabel users"""
        print("\nMelakukan seeding tabel users...")
        
        for i in range(SEEDING_CONFIG['users']['admin_count']):
            full_name = self.fake.name()
            user_data = (
                full_name,
                self.hash_password('admin123'),
                self.generate_email_from_name(full_name),
                self.generate_indonesian_phone(),
                'admin'
            )
            
            self.cursor.execute("""
                INSERT INTO users (full_name, password_hash, email, phone_number, type)
                VALUES (%s, %s, %s, %s, %s) RETURNING user_id
            """, user_data)
            
            user_id = self.cursor.fetchone()[0]
            self.users.append({'id': user_id, 'type': 'admin'})
        
        for i in range(SEEDING_CONFIG['users']['customer_count']):
            full_name = self.fake.name()
            user_data = (
                full_name,
                self.hash_password('customer123'),
                self.generate_email_from_name(full_name),
                self.generate_indonesian_phone(),
                'customer'
            )
            
            self.cursor.execute("""
                INSERT INTO users (full_name, password_hash, email, phone_number, type)
                VALUES (%s, %s, %s, %s, %s) RETURNING user_id
            """, user_data)
            
            user_id = self.cursor.fetchone()[0]
            self.users.append({'id': user_id, 'type': 'customer'})
        
        self.connection.commit()
        print(f"  Berhasil membuat {len(self.users)} users")
    
    def seed_coaches(self):
        """Seeding tabel coaches"""
        print("Melakukan seeding tabel coaches...")
        
        sport_configs = {
            'tennis': SEEDING_CONFIG['coaches']['tennis_coaches'],
            'pickleball': SEEDING_CONFIG['coaches']['pickleball_coaches'],
            'padel': SEEDING_CONFIG['coaches']['padel_coaches']
        }
        
        for sport, count in sport_configs.items():
            available_prices = SEEDING_CONFIG['coaches']['predefined_prices'][sport]
            
            for i in range(count):
                coach_data = (
                    f"Coach {self.fake.name()}",
                    sport,
                    random.choice(available_prices)
                )
                
                self.cursor.execute("""
                    INSERT INTO coaches (coach_name, sport, course_price)
                    VALUES (%s, %s, %s) RETURNING coach_id
                """, coach_data)
                
                coach_id = self.cursor.fetchone()[0]
                self.coaches.append({
                    'id': coach_id,
                    'sport': sport,
                    'price': coach_data[2]
                })
        
        self.connection.commit()
        print(f"  Berhasil membuat {len(self.coaches)} coaches")
    
    def seed_fields(self):
        """Seeding tabel fields"""
        print("Melakukan seeding tabel fields...")
        
        sport_configs = {
            'tennis': SEEDING_CONFIG['fields']['tennis_fields'],
            'pickleball': SEEDING_CONFIG['fields']['pickleball_fields'],
            'padel': SEEDING_CONFIG['fields']['padel_fields']
        }
        
        field_counter = 1
        for sport, count in sport_configs.items():
            available_prices = SEEDING_CONFIG['fields']['predefined_rental_prices'][sport]
            
            for i in range(count):
                field_data = (
                    f"Lapangan {sport.capitalize()} {field_counter}",
                    sport,
                    random.choice(available_prices)
                )
                
                self.cursor.execute("""
                    INSERT INTO fields (field_name, sport, rental_price)
                    VALUES (%s, %s, %s) RETURNING field_id
                """, field_data)
                
                field_id = self.cursor.fetchone()[0]
                self.fields.append({
                    'id': field_id,
                    'sport': sport,
                    'price': field_data[2]
                })
                field_counter += 1
        
        self.connection.commit()
        print(f"  Berhasil membuat {len(self.fields)} fields")
    
    def seed_coach_availability(self):
        """Seeding tabel coachavailability"""
        print("Melakukan seeding tabel coachavailability...")
        
        config = SEEDING_CONFIG['coachavailability']
        today = datetime.now().date()
        start_date = today - timedelta(days=config['days_before'])
        end_date = today + timedelta(days=config['days_ahead'])
        total_days = config['days_before'] + config['days_ahead']
        
        used_combinations = set()
        
        for coach in self.coaches:
            min_slots = int(config['slots_per_coach'] * 0.7)
            max_slots = config['slots_per_coach']
            target_slots = random.randint(min_slots, max_slots)
            
            coach_slots_created = 0
            max_attempts = target_slots * 3
            attempts = 0
            
            while coach_slots_created < target_slots and attempts < max_attempts:
                date = start_date + timedelta(days=random.randint(0, total_days))
                hour = random.randint(config['hours_range'][0], config['hours_range'][1])
                
                combination = (coach['id'], date, hour)
                
                if combination not in used_combinations:
                    try:
                        self.cursor.execute("""
                            INSERT INTO coachavailability (coach_id, date, hour)
                            VALUES (%s, %s, %s) RETURNING coach_availability_id
                        """, combination)
                        
                        availability_id = self.cursor.fetchone()[0]
                        self.coach_availabilities.append({
                            'id': availability_id,
                            'coach_id': coach['id'],
                            'date': date,
                            'hour': hour
                        })
                        
                        used_combinations.add(combination)
                        coach_slots_created += 1
                        
                    except psycopg2.IntegrityError:
                        self.connection.rollback()
                
                attempts += 1
            
        print(f"  Berhasil membuat {len(self.coach_availabilities)} total coachavailability")
    
    def seed_field_bookings(self):
        """Seeding tabel fieldbookingdetail"""
        print("Melakukan seeding tabel fieldbookingdetail")
        
        for course in self.group_courses:
            self.cursor.execute("""
                SELECT field_id, date, start_hour 
                FROM groupcourses 
                WHERE course_id = %s
            """, (course['id'],))
            
            course_details = self.cursor.fetchone()
            if course_details:
                field_id, date, start_hour = course_details
                
                try:
                    self.cursor.execute("""
                        INSERT INTO fieldbookingdetail (field_id, date, hour)
                        VALUES (%s, %s, %s) RETURNING field_booking_detail_id
                    """, (field_id, date, start_hour))
                    
                    booking_id = self.cursor.fetchone()[0]
                    self.field_bookings.append({
                        'id': booking_id,
                        'field_id': field_id,
                        'date': date,
                        'hour': start_hour,
                        'course_id': course['id']
                    })
                    
                except psycopg2.IntegrityError:
                    self.connection.rollback()
                    print(f"    Warning: Field booking conflict for field {field_id} on {date} at {start_hour}:00")
        
        self.connection.commit()
        print(f"  Berhasil membuat {len(self.field_bookings)} fieldbookingdetail (semua terikat dengan group courses)")
    
    def create_payment_for_course(self, course_price, course_type="group"):
        """Helper method untuk membuat payment saat course order dibuat"""
        config = SEEDING_CONFIG['payments']
        status_options = ['waiting', 'accepted', 'rejected']
        
        base_amount = course_price
        additional_fees = random.randint(0, 50000) 
        total_payment = base_amount + additional_fees
        
        status = random.choices(
            status_options,
            weights=[
                config['status_distribution']['waiting'],
                config['status_distribution']['accepted'],
                config['status_distribution']['rejected']
            ]
        )[0]
        
        payment_proof = None
        if status in ['accepted', 'rejected']:
            payment_proof = f"Bukti transfer untuk {course_type} course - {self.fake.text(max_nb_chars=50)}"
        
        today = datetime.now()
        start_date = today - timedelta(days=config['days_before'])
        end_date = today + timedelta(days=config['days_ahead'])
        payment_date = self.fake.date_time_between(start_date=start_date, end_date=end_date)
        
        self.cursor.execute("""
            INSERT INTO payments (total_payment, payment_proof, status, payment_date)
            VALUES (%s, %s, %s, %s) RETURNING payment_id
        """, (total_payment, payment_proof, status, payment_date))
        
        payment_id = self.cursor.fetchone()[0]
        
        payment_data = {
            'id': payment_id,
            'amount': total_payment,
            'status': status,
            'date': payment_date
        }
        self.payments.append(payment_data)
        
        return payment_id, payment_data
    
    def try_use_voucher(self, customer_id, payment_id):
        """Coba gunakan voucher yang tersedia untuk customer, jika ada"""
        today = datetime.now()
        
        available_vouchers = [
            v for v in self.vouchers 
            if v['customer_id'] == customer_id 
            and not v['used'] 
            and v['expired_at'] > today
        ]
        
        if available_vouchers and random.random() < 0.3: 
            voucher = max(available_vouchers, key=lambda x: x['discount'])
            
            self.cursor.execute("""
                UPDATE vouchers 
                SET used = TRUE, payment_id = %s 
                WHERE voucher_id = %s
            """, (payment_id, voucher['id']))
            
            voucher['used'] = True
            voucher['payment_id'] = payment_id
            
            return voucher
        
        return None
    
    def seed_payments(self):
        """Seeding tabel payments"""
        print("Melakukan seeding tabel payments...")

        config = SEEDING_CONFIG['payments']
        status_options = ['waiting', 'accepted', 'rejected']
        
        today = datetime.now()
        start_date = today - timedelta(days=config['days_before'])
        end_date = today + timedelta(days=config['days_ahead'])
        
        for i in range(config['base_count']):
            amount = random.randint(100000, 2000000)
            status = random.choices(
                status_options,
                weights=[
                    config['status_distribution']['waiting'],
                    config['status_distribution']['accepted'],
                    config['status_distribution']['rejected']
                ]
            )[0]
            
            payment_proof = self.fake.text(max_nb_chars=100) if status in ['accepted', 'rejected'] else None
            payment_date = self.fake.date_time_between(start_date=start_date, end_date=end_date)
            
            self.cursor.execute("""
                INSERT INTO payments (total_payment, payment_proof, status, payment_date)
                VALUES (%s, %s, %s, %s) RETURNING payment_id
            """, (amount, payment_proof, status, payment_date))
            
            payment_id = self.cursor.fetchone()[0]
            self.payments.append({
                'id': payment_id,
                'amount': amount,
                'status': status
            })
        
        self.connection.commit()
        print(f"  Berhasil membuat {len(self.payments)} payments")
    
    def seed_group_courses(self):
        """Seeding tabel groupcourses"""
        print("Melakukan seeding tabel groupcourses...")

        config = SEEDING_CONFIG['groupcourses']
        today = datetime.now().date()
        start_date = today - timedelta(days=config['days_before'])
        total_days = config['days_before'] + config['days_ahead']
        sports = ['tennis', 'pickleball', 'padel']
        
        used_combinations = set()
        
        for coach in self.coaches:
            min_courses = int(config['slots_per_coach'] * 0.7)
            max_courses = config['slots_per_coach']
            target_courses = random.randint(min_courses, max_courses)
            
            coach_courses_created = 0
            max_attempts = target_courses * 3
            attempts = 0
            
            coach_sport_fields = [f for f in self.fields if f['sport'] == coach['sport']]
            
            if not coach_sport_fields:
                continue
            
            while coach_courses_created < target_courses and attempts < max_attempts:
                date = start_date + timedelta(days=random.randint(0, total_days))
                start_hour = random.randint(6, 20)
                field = random.choice(coach_sport_fields)
                
                combination = (coach['id'], field['id'], date, start_hour)
                
                if combination in used_combinations:
                    attempts += 1
                    continue
                
                quota = random.randint(config['quota_range'][0], config['quota_range'][1])
                course_price = random.choice(config['predefined_prices'][coach['sport']])
                
                try:
                    self.cursor.execute("""
                        INSERT INTO groupcourses (course_name, coach_id, sport, field_id, date, start_hour, course_price, quota)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s) RETURNING course_id
                    """, (
                        f"Kursus Grup {coach['sport'].capitalize()} {len(self.group_courses) + 1}",
                        coach['id'],
                        coach['sport'],
                        field['id'],
                        date,
                        start_hour,
                        course_price,
                        quota
                    ))
                    
                    course_id = self.cursor.fetchone()[0]
                    self.group_courses.append({
                        'id': course_id,
                        'sport': coach['sport'],
                        'quota': quota,
                        'price': course_price
                    })
                    
                    used_combinations.add(combination)
                    coach_courses_created += 1
                    
                except psycopg2.IntegrityError:
                    self.connection.rollback()
                
                attempts += 1
        
        self.connection.commit()
        print(f"  Berhasil membuat {len(self.group_courses)} groupcourses")
    
    def seed_group_course_orders(self):
        """Seeding tabel groupcoursesorders dan groupcourseorderdetail"""
        print("Melakukan seeding tabel groupcoursesorders dan groupcoursesorderdetail...")
        
        config = SEEDING_CONFIG['groupcourseorder']
        customer_users = [u for u in self.users if u['type'] == 'customer']
        
        courses_to_order = random.sample(
            self.group_courses,
            int(len(self.group_courses) * config['orders_percentage'])
        )
        
        for course in courses_to_order:
            customer = random.choice(customer_users)
            pax_count = random.randint(1, min(course['quota'], 10))
            
            total_course_price = course['price'] * pax_count
            
            payment_id, payment_data = self.create_payment_for_course(total_course_price, "group")
            
            used_voucher = self.try_use_voucher(customer['id'], payment_id)
            
            self.cursor.execute("""
                INSERT INTO groupcourseorder (customer_id, payment_id)
                VALUES (%s, %s) RETURNING group_course_order_id
            """, (customer['id'], payment_id))
            
            order_id = self.cursor.fetchone()[0]
            
            self.cursor.execute("""
                INSERT INTO groupcourseorderdetail (group_course_order_id, course_id, pax_count)
                VALUES (%s, %s, %s)
            """, (order_id, course['id'], pax_count))
            
            self.group_course_orders.append({
                'id': order_id,
                'course_id': course['id'],
                'pax_count': pax_count,
                'payment_id': payment_id,
                'payment_status': payment_data['status'],
                'used_voucher': used_voucher is not None,
                'voucher_discount': used_voucher['discount'] if used_voucher else 0
            })
        
        self.connection.commit()
        
        voucher_used_count = sum(1 for order in self.group_course_orders if order['used_voucher'])
        print(f"  Berhasil membuat {len(self.group_course_orders)} group course orders dengan payments")
        print(f"    {voucher_used_count} orders menggunakan voucher")
    
    def seed_private_course_orders(self):
        """Seeding tabel privatecourseorder dan privatecourseorderdetail dengan payments"""
        print("Melakukan seeding tabel privatecourseorder, privatecourseorderdetail, dan payments...")
        
        config = SEEDING_CONFIG['privatecourseorder']
        customer_users = [u for u in self.users if u['type'] == 'customer']
        
        availabilities_to_book = random.sample(
            self.coach_availabilities,
            int(len(self.coach_availabilities) * config['orders_percentage'])
        )
        
        for availability in availabilities_to_book:
            customer = random.choice(customer_users)
            
            coach_data = next(c for c in self.coaches if c['id'] == availability['coach_id'])
            coach_price = coach_data['price']
            
            payment_id, payment_data = self.create_payment_for_course(coach_price, "private")
            
            used_voucher = self.try_use_voucher(customer['id'], payment_id)
            
            self.cursor.execute("""
                INSERT INTO privatecourseorder (customer_id, payment_id)
                VALUES (%s, %s) RETURNING private_course_order_id
            """, (customer['id'], payment_id))
            
            order_id = self.cursor.fetchone()[0]
            
            self.cursor.execute("""
                INSERT INTO privatecourseorderdetail (private_course_order_id, coach_availability_id)
                VALUES (%s, %s)
            """, (order_id, availability['id']))
            
            self.private_course_orders.append({
                'id': order_id,
                'availability_id': availability['id'],
                'payment_id': payment_id,
                'payment_status': payment_data['status'],
                'used_voucher': used_voucher is not None,
                'voucher_discount': used_voucher['discount'] if used_voucher else 0
            })
        
        self.connection.commit()
        
        voucher_used_count = sum(1 for order in self.private_course_orders if order['used_voucher'])
        print(f"  Berhasil membuat {len(self.private_course_orders)} private course orders dengan payments")
        print(f"    {voucher_used_count} orders menggunakan voucher")
    
    def seed_vouchers(self):
        """Seeding tabel vouchers - dibuat tanpa payment_id, akan digunakan saat order dibuat"""
        print("Melakukan seeding tabel voucher (belum terpakai)...")
        
        config = SEEDING_CONFIG['vouchers']
        customer_users = [u for u in self.users if u['type'] == 'customer']
        
        today = datetime.now()
        past_date = today - timedelta(days=config['days_before'])
        future_date = today + timedelta(days=config['days_ahead'])
        
        self.vouchers = []
        
        for customer in customer_users:
            voucher_count = random.randint(1, config['vouchers_per_customer'])
            
            for _ in range(voucher_count):
                discount = random.choice(config['predefined_discounts'])
                
                expired_at = self.fake.date_time_between(start_date=past_date, end_date=future_date)
                
                self.cursor.execute("""
                    INSERT INTO vouchers (payment_id, customer_id, discount, expired_at, used)
                    VALUES (%s, %s, %s, %s, %s) RETURNING voucher_id
                """, (None, customer['id'], discount, expired_at, False))
                
                voucher_id = self.cursor.fetchone()[0]
                self.vouchers.append({
                    'id': voucher_id,
                    'customer_id': customer['id'],
                    'discount': discount,
                    'expired_at': expired_at,
                    'used': False
                })
        
        self.connection.commit()
        
        self.cursor.execute("SELECT COUNT(*) FROM vouchers")
        voucher_count = self.cursor.fetchone()[0]
        print(f"  Berhasil membuat {voucher_count} vouchers")

    def run_seeding(self):
        """Menjalankan proses seeding"""
        try:
            self.connect_database()
            print("Memulai proses seeding database...")
            
            self.clear_all_data()
            self.seed_users()
            self.seed_coaches()
            self.seed_fields()
            self.seed_coach_availability()
            self.seed_group_courses()
            self.seed_field_bookings()
            self.seed_vouchers()
            self.seed_group_course_orders()  
            self.seed_private_course_orders()
            
            print("\nSeeding database berhasil diselesaikan!")
            
        except Exception as e:
            print(f"\nError selama proses seeding: {e}")
            if self.connection:
                self.connection.rollback()
        finally:
            self.close_connection()

if __name__ == "__main__":
    
    seeder = DatabaseSeeder()
    seeder.run_seeding()
