"""
Konfigurasi untuk koneksi database dan seeding data.
"""

# Konfigurasi Database PostgreSQL
DATABASE_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'pdl_project_0',
    'user': 'postgres',
    'password': 'chomusuke'
}

# Konfigurasi Seeding
SEEDING_CONFIG = {
    'users': {
        'total': 200,
        'admin_count': 5, 
        'customer_count': 195 
    },
    'coaches': {
        'total': 15,
        'tennis_coaches': 5,
        'pickleball_coaches': 5,
        'padel_coaches': 5,
        'predefined_prices': {
            'tennis': [75000, 100000, 125000, 150000, 175000, 200000, 225000, 250000],     
            'pickleball': [50000, 65000, 80000, 95000, 110000, 125000, 150000, 180000],  
            'padel': [80000, 100000, 120000, 140000, 160000, 180000, 200000, 220000]       
        }
    },
    'fields': {
        'total': 15,
        'tennis_fields': 5,
        'pickleball_fields': 5,
        'padel_fields': 5,
        'predefined_rental_prices': {
            'tennis': [150000, 200000, 250000, 300000, 350000, 400000, 450000, 500000, 550000, 600000],    
            'pickleball': [100000, 130000, 160000, 190000, 220000, 250000, 280000, 320000, 360000, 400000], 
            'padel': [120000, 160000, 200000, 240000, 280000, 320000, 360000, 400000, 450000, 500000]       
        }
    },
    'coachavailability': {
        'slots_per_coach': 20, 
        'days_ahead': 30, 
        'hours_range': (6, 21)
    },
    'fieldbookingdetail': {
        'bookings_percentage': 0.3 
    },
    'groupcourses': {
        'total': 50,
        'days_ahead': 30,  
        'quota_range': (5, 20), 
        'predefined_prices': {
            'tennis': [200000, 250000, 300000, 350000, 400000, 450000, 500000],    
            'pickleball': [150000, 180000, 210000, 240000, 270000, 300000, 350000], 
            'padel': [180000, 220000, 260000, 300000, 340000, 380000, 420000, 450000] 
        }
    },
    'payments': {
        'base_count': 50,  
        'status_distribution': {
            'waiting': 0.2,
            'accepted': 0.7,
            'rejected': 0.1
        }
    },
    'groupcourseorder': {
        'orders_percentage': 0.6  # 60% dari kursus grup akan memiliki pesanan
    },
    'privatecourseorder': {
        'orders_percentage': 0.4  # 40% dari ketersediaan coach akan memiliki pesanan privat
    },
    'vouchers': {
        'vouchers_per_customer': 2, 
        'predefined_discounts': [5, 10, 15, 20, 25, 30, 35, 40, 50],  
        'used_percentage': 0.3  
    }
}
