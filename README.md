# Sports Management System Database

## A. Instalasi & Setup

### 1. Persyaratan Sistem

- PostgreSQL Server
- Python 3.7+
- Package Python yang diperlukan:
  ```bash
  pip install -r requirements.txt
  ```
  atau install manual:
  ```bash
  pip install psycopg2-binary faker
  ```

### 2. Konfigurasi Database

1. Pastikan PostgreSQL berjalan
2. Update konfigurasi di `scripts/config.py` dengan kredensial database Anda
3. Buat database `pdl_project_0` di PostgreSQL

### 3. Penggunaan

#### Menjalankan Seeding Database

```bash
cd scripts
python seed.py
```

## B. Struktur Database

### 1. Tipe Data dan Enum

- `sport_type`: enum('tennis','pickleball','padel')
- `user_type`: enum('admin','customer')
- `payment_status_type`: enum('waiting','accepted','rejected')

### 2. Constraint dan Aturan Tabel

#### 1) coachavailability

- **Kolom**: coach_availability_id (PK), coach_id (FK -> coaches.coach_id ON DELETE CASCADE), date, hour
- **Constraint hour**: harus antara 6 dan 21 (inklusif)
- **Trigger**: prevent_coach_double_booking_trigger memanggil check_coach_double_booking() untuk menghindari double booking coach pada tanggal/jam yang sama

#### 2) coaches

- **Kolom**: coach_id (PK), coach_name, sport (sport_type), course_price
- **sport**: menggunakan enum sport_type

#### 3) fieldbookingdetail

- **Kolom**: field_booking_detail_id (PK), field_id (FK -> fields.field_id ON DELETE CASCADE), date, hour
- **Constraint hour**: harus antara 6 dan 20 (inklusif)
- **Catatan**: Booking model dalam aplikasi menggunakan blok 2 jam; pencegahan double booking harus mempertimbangkan kedua jam dalam blok tersebut

#### 4) fields

- **Kolom**: field_id (PK), field_name, sport (sport_type), rental_price
- **sport**: menggunakan enum sport_type

#### 5) groupcourseorder

- **Kolom**: group_course_order_id (PK), customer_id (FK -> users.user_id ON DELETE CASCADE), payment_id (FK -> payments.payment_id ON DELETE CASCADE)

#### 6) groupcourseorderdetail

- **Kolom**: group_course_order_detail_id (PK), group_course_order_id (FK -> groupcourseorder.group_course_order_id), course_id (FK -> groupcourses.course_id), pax_count (NOT NULL)
- **Trigger**: check_course_quota() diterapkan melalui check_course_quota_trigger untuk memastikan total pax_count di semua detail pesanan tidak melebihi kuota kursus grup

#### 7) groupcourses

- **Kolom**: course_id (PK), course_name, coach_id (FK -> coaches.coach_id ON DELETE SET NULL), sport (sport_type), field_id (FK -> fields.field_id ON DELETE SET NULL), date, start_hour, course_price, quota
- **Constraint start_hour**: harus antara 6 dan 20 (inklusif)
- **Trigger**: prevent_double_booking memanggil check_field_availability() untuk menghindari konflik jadwal di lapangan

#### 8) payments

- **Kolom**: payment_id (PK), total_payment (NOT NULL), payment_proof (text), status (payment_status_type DEFAULT 'waiting' NOT NULL), payment_date (timestamp)

#### 9) privatecourseorder

- **Kolom**: private_course_order_id (PK), customer_id (FK -> users.user_id ON DELETE CASCADE), payment_id (FK -> payments.payment_id ON DELETE CASCADE)

#### 10) privatecourseorderdetail

- **Kolom**: private_course_order_detail_id (PK), private_course_order_id (FK -> privatecourseorder.private_course_order_id ON DELETE CASCADE), coach_availability_id (FK -> coachavailability.coach_availability_id ON DELETE CASCADE)

#### 11) users

- **Kolom**: user_id (PK), full_name (NOT NULL), password_hash (NOT NULL), email (NOT NULL, UNIQUE), phone_number (NOT NULL), type (user_type DEFAULT 'customer' NOT NULL)
- **email**: memiliki constraint UNIQUE

#### 12) vouchers

- **Kolom**: voucher_id (PK), payment_id (FK -> payments.payment_id ON DELETE CASCADE), customer_id (FK -> users.user_id ON DELETE CASCADE), discount (NOT NULL), expired_at (timestamp NOT NULL), used (boolean DEFAULT false NOT NULL)

## C. Struktur Folder

```
Project_0/
├── scripts/          # Script Python dan konfigurasi
│   ├── seed.py       # Script seeding database
│   └── config.py     # Konfigurasi database dan file
├── dump/             # File dump database
│   ├── dump_pdl_project_0.sql
│   └── dump.sql
├── requirements.txt  # Dependensi Python
└── README.md         # Dokumentasi ini
```
