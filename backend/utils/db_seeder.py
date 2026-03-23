import os
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
from passlib.context import CryptContext
import random
import uuid

# Initialize Firebase Admin securely
key_path = os.path.join(os.path.dirname(__file__), '../database/serviceAccountKey.json')

cred = credentials.Certificate(key_path)
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# 1. FINAL AUTHORIZED COLLECTIONS (Used by the active Python codebase)
FINAL_COLLECTIONS = [
    'users',
    'bus_routes',
    'ticket_prices',
    'admin_settings',
    'trips',
    'passenger_logs',
    'driver_behavior_logs',
    'alert_history',
    'gps_tracking_history',
    'lost_found_items',
    'lost_found_claim_requests',
    'LIVE-STATUS'
]

# Obsolete / Deprecated collections to aggressively wipe
OBSOLETE_COLLECTIONS = [
    'user_profiles', 'role_permissions', 'buses', 'trip_financials', 'summary_statistics'
]

def wipe_database():
    print("🧹 Stage 1: Wiping ALL existing database collections (including obsolete ones)...")
    all_collections_to_wipe = FINAL_COLLECTIONS + OBSOLETE_COLLECTIONS
    
    deleted_counts = {}
    for coll_name in all_collections_to_wipe:
        docs = db.collection(coll_name).get()
        count = 0
        for doc in docs:
            doc.reference.delete()
            count += 1
        deleted_counts[coll_name] = count
        if count > 0:
            print(f"   -> Deleted {count} documents from '{coll_name}'")
    print("✅ Database cleanly wiped.\n")
    return deleted_counts

def seed_infrastructure():
    print("🏗️ Stage 2: Seeding Infrastructure (Users, Routes, Settings)...")
    counts = {'users': 0, 'bus_routes': 0, 'ticket_prices': 0, 'admin_settings': 0}
    
    # Passwords
    pw_hash = pwd_context.hash('password')
    
    # Admin
    db.collection('users').document('admin-01').set({
        'email': 'admin@shuttle.lk', 'password_hash': pw_hash, 
        'role': 'admin', 'name': 'Mitheja Admin', 'status': 'active'
    })
    counts['users'] += 1
    
    # Driver
    db.collection('users').document('driver-01').set({
        'email': 'driver@shuttle.lk', 'password_hash': pw_hash, 
        'role': 'driver', 'name': 'Kamal Perera', 'status': 'active'
    })
    counts['users'] += 1
    
    # Students
    for i in range(1, 6):
        db.collection('users').document(f'student-0{i}').set({
            'email': f'student{i}@shuttle.lk', 'password_hash': pw_hash, 
            'role': 'student', 'name': f'Student User {i}', 'status': 'active'
        })
        counts['users'] += 1

    # Ticket Prices
    db.collection('ticket_prices').document('standard_fares').set({
        'price_75': 75, 'price_100': 100, 'price_150': 150, 'price_200': 200, 
        'updatedAt': datetime.now().isoformat()
    })
    counts['ticket_prices'] += 1

    # Admin Settings
    db.collection('admin_settings').document('global_config').set({
        'operating_cost_per_trip': 4000,
        'leakage_alert_threshold_percent': 10,
        'notifications_enabled': True
    })
    counts['admin_settings'] += 1

    # Route
    db.collection('bus_routes').document('RT-001').set({
        'name': 'Campus <-> Peradeniya Main',
        'active_buses': ['NB-2341'],
        'waypoints': [
            {"lat": 7.2544, "lng": 80.5916, "stop_name": "Main Gate"},
            {"lat": 7.2588, "lng": 80.5988, "stop_name": "Library Phase"},
            {"lat": 7.2621, "lng": 80.6010, "stop_name": "Peradeniya Terminal"}
        ]
    })
    counts['bus_routes'] += 1

    # Live Status map tracker
    db.collection('LIVE-STATUS').document('NB-2341').set({
        'latitude': 7.2588, 'longitude': 80.5988, 'speed': 0.0,
        'status': 'active', 'last_updated': datetime.now().isoformat()
    })
    
    return counts

def seed_30_day_history():
    print("📈 Stage 3: Generative 30-Day Sub-System Simulation (Trips, Telemetry, Alerts)...")
    counts = {
        'trips': 0, 'passenger_logs': 0, 'driver_behavior_logs': 0, 
        'alert_history': 0, 'gps_tracking_history': 0,
        'lost_found_items': 0, 'lost_found_claim_requests': 0
    }
    
    now = datetime.now()
    FIXED_COST = 4000
    
    # Generate 30 days of data
    for day_offset in range(30, -1, -1):
        target_date = now - timedelta(days=day_offset)
        date_str = target_date.strftime("%Y-%m-%d")
        
        # ── MORNING TRIP (Usually profitable, high demand) ──
        m_id = f"TRP-{date_str}-M"
        m_ai = random.randint(55, 75)
        m_sold = random.randint(50, m_ai)
        m_unpaid = m_ai - m_sold
        m_rev = m_sold * 75
        
        db.collection('trips').document(m_id).set({
            'date': date_str, 'tripType': 'Morning', 'status': 'completed',
            'driverId': 'driver-01', 'busId': 'NB-2341',
            'aiPassengerCount': m_ai, 'soldTicketCount': m_sold,
            'unpaidPassengerCount': m_unpaid, 'revenueLeakage': m_unpaid * 75,
            'actualRevenue': m_rev, 'profitOrLoss': m_rev - FIXED_COST,
            'fixedCost': FIXED_COST, 'actualEndTime': target_date.isoformat()
        })
        counts['trips'] += 1
        
        # Passenger logs for Morning
        db.collection('passenger_logs').add({
            'bus_id': 'NB-2341', 'trip_id': m_id, 'detected_count': m_ai, 
            'timestamp': target_date.isoformat()
        })
        counts['passenger_logs'] += 1

        # ── EVENING TRIP (Variable demand, sometimes un-profitable) ──
        e_id = f"TRP-{date_str}-E"
        e_ai = random.randint(20, 50)
        e_sold = random.randint(15, e_ai)
        e_unpaid = e_ai - e_sold
        e_rev = e_sold * 75
        
        # Simulating anomaly alerts (e.g., Extreme Leakage > 20%)
        if e_ai > 0 and (e_unpaid / e_ai) > 0.20:
             db.collection('alert_history').add({
                 'bus_id': 'NB-2341', 'driver_id': 'driver-01',
                 'type': 'Revenue Leakage', 'description': f'High evasion detected on {date_str} Evening',
                 'status': 'unread', 'timestamp': target_date.isoformat()
             })
             counts['alert_history'] += 1

        db.collection('trips').document(e_id).set({
            'date': date_str, 'tripType': 'Evening', 'status': 'completed',
            'driverId': 'driver-01', 'busId': 'NB-2341',
            'aiPassengerCount': e_ai, 'soldTicketCount': e_sold,
            'unpaidPassengerCount': e_unpaid, 'revenueLeakage': e_unpaid * 75,
            'actualRevenue': e_rev, 'profitOrLoss': e_rev - FIXED_COST,
            'fixedCost': FIXED_COST, 'actualEndTime': (target_date + timedelta(hours=8)).isoformat()
        })
        counts['trips'] += 1
        
        db.collection('passenger_logs').add({
            'bus_id': 'NB-2341', 'trip_id': e_id, 'detected_count': e_ai, 
            'timestamp': (target_date + timedelta(hours=8)).isoformat()
        })
        counts['passenger_logs'] += 1

        # ── RANDOMIZED EVENTS ──
        
        # 1. Driver Behavior (15% chance per day)
        if random.random() < 0.15:
            events = ['drowsiness', 'harsh_braking', 'speeding', 'phone_usage']
            ev = random.choice(events)
            sev = 'critical' if ev in ['drowsiness', 'speeding'] else 'warning'
            
            db.collection('driver_behavior_logs').add({
                'bus_id': 'NB-2341', 'driver_id': 'driver-01',
                'event_type': ev, 'severity': sev, 'confidence': round(random.uniform(0.70, 0.98), 2),
                'timestamp': target_date.isoformat()
            })
            counts['driver_behavior_logs'] += 1
            
            if sev == 'critical':
                db.collection('alert_history').add({
                    'bus_id': 'NB-2341', 'driver_id': 'driver-01',
                    'type': 'driver_behavior', 'description': f'Critical {ev} detected!',
                    'status': 'unread' if day_offset < 3 else 'resolved',
                    'timestamp': target_date.isoformat()
                })
                counts['alert_history'] += 1

        # 2. GPS History (just some trace points for the routes)
        if day_offset < 5:  # Only seed rich GPS for the last 5 days
            db.collection('gps_tracking_history').add({
                 'bus_id': 'NB-2341', 'latitude': 7.25 + random.uniform(0, 0.01),
                 'longitude': 80.59 + random.uniform(0, 0.01), 'speed': random.randint(15, 45),
                 'timestamp': target_date.isoformat()
            })
            counts['gps_tracking_history'] += 1

        # 3. Lost & Found Items (10% chance per day)
        if random.random() < 0.10:
            item_id = f"LF-{uuid.uuid4().hex[:6].upper()}"
            items = ['Black Backpack', 'Umbrella', 'Laptop Case', 'Water Bottle', 'Jacket']
            status_opts = ['pending', 'claimRequested', 'verified', 'claimed']
            chosen_status = random.choice(status_opts)
            
            payload = {
                'type': random.choice(items),
                'date_found': date_str,
                'status': chosen_status,
                'busId': 'NB-2341'
            }
            
            if chosen_status != 'pending':
                payload['claimedBy'] = 'student-01'
            if chosen_status == 'verified':
                payload['verifiedBy'] = 'admin-01'
            if chosen_status == 'claimed':
                payload['verifiedBy'] = 'admin-01'
                payload['handedOverBy'] = 'admin-01'
            
            db.collection('lost_found_items').document(item_id).set(payload)
            counts['lost_found_items'] += 1
            
            # If a claim exists, seed the ledger
            if chosen_status != 'pending':
                db.collection('lost_found_claim_requests').add({
                    'item_id': item_id, 'student_id': 'student-01',
                    'timestamp': target_date.isoformat(),
                    'status': 'approved' if chosen_status in ['verified', 'claimed'] else 'pending_verification'
                })
                counts['lost_found_claim_requests'] += 1

    return counts

if __name__ == "__main__":
    print("="*60)
    print("🚀 SMART SHUTTLE AI - PRODUCTION DATABASE RE-GENERATOR")
    print("="*60)
    
    wipe_counts = wipe_database()
    infra_counts = seed_infrastructure()
    sim_counts = seed_30_day_history()
    
    print("\n" + "="*60)
    print("📊 FINAL SEEDING REPORT")
    print("="*60)
    print("--- 1. ACTIVE COLLECTIONS SOURCED ---")
    for c in FINAL_COLLECTIONS:
        print(f" ✔ {c}")
    
    print("\n--- 2. OBSOLETE COLLECTIONS DESTROYED ---")
    for c in OBSOLETE_COLLECTIONS:
        print(f" ❌ {c} (Purged {wipe_counts.get(c, 0)} old records)")
        
    print("\n--- 3. TEST CREDENTIALS (Password: 'password') ---")
    print(" 👑 admin@shuttle.lk")
    print(" 🚌 driver@shuttle.lk")
    for i in range(1, 6):
        print(f" 🎓 student{i}@shuttle.lk")
        
    print("\n--- 4. INJECTED RECORD METRICS ---")
    final_tallies = {**infra_counts, **sim_counts}
    for k, v in final_tallies.items():
        print(f" ➕ {k}: {v} records inserted.")
        
    print("\n🌟 DATABASE RESET COMPLETE. Frontend dashboards will perfectly sync.")
    print("="*60)
