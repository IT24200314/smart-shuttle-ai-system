import os
import time
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# =====================================================================
# AI Backend Revenue Engine
# This script bridges the YOLOv11 AI model with the Firebase Database.
# 
# Usage for Future AI Script:
#   from revenue_engine import RevenueEngine
#   engine = RevenueEngine("serviceAccountKey.json")
#   
#   # Whenever YOLO detects new passengers entering, simply call:
#   engine.process_new_passengers(bus_id="bus_001", headcount_increase=3)
# =====================================================================

class RevenueEngine:
    def __init__(self, key_path=r"C:\suttle project\smart-shuttle-ai-system\backend\database\serviceAccountKey.json"):
        """Initializes the connection to Firebase."""
        if not firebase_admin._apps:
            try:
                cred = credentials.Certificate(key_path)
                firebase_admin.initialize_app(cred)
                print("✅ Revenue Engine: Connected to Firebase.")
            except Exception as e:
                print(f"❌ Failed to connect to Firebase: {e}")
                print(f"Ensure you have 'serviceAccountKey.json' at {key_path}")
                exit(1)
        self.db = firestore.client()
        # In-memory cache for ticket prices to reduce database reads
        self.price_cache = {}

    def _get_ticket_price(self, bus_id):
        """Fetches the ticket price for a specific bus from Firebase (or cache)."""
        if bus_id in self.price_cache:
            return self.price_cache[bus_id]

        doc_ref = self.db.collection('ticket_prices').document(bus_id)
        doc = doc_ref.get()
        if doc.exists:
            data = doc.to_dict()
            price = data.get('cost_per_passenger', 75.0) # Default to user-specified 75.0
            self.price_cache[bus_id] = price
            return price
        else:
            print(f"⚠️ Warning: No ticket price found for {bus_id}. Defaulting to 75.0 LKR.")
            return 75.0

    def process_new_passengers(self, bus_id, headcount_increase):
        """
        Receives the counted passengers from the YOLO AI, calculates revenue, 
        and updates the 'passenger_logs' log for today.
        """
        if headcount_increase <= 0:
            return  # Nothing to do

        price = self._get_ticket_price(bus_id)
        revenue_increase = headcount_increase * price
        
        # We record totals based on CURRENT date
        today_str = datetime.now().strftime("%Y-%m-%d")
        log_ref = self.db.collection('passenger_logs').document(today_str)

        try:
            # Transaction ensures accurate counts if multiple cameras update simultaneously
            @firestore.transactional
            def update_in_transaction(transaction, log_ref):
                snapshot = log_ref.get(transaction=transaction)
                if snapshot.exists:
                    current_data = snapshot.to_dict()
                    new_passengers = current_data.get('total_passengers', 0) + headcount_increase
                    new_revenue = current_data.get('total_revenue_lkr', 0.0) + revenue_increase
                    
                    transaction.update(log_ref, {
                        'total_passengers': new_passengers,
                        'total_revenue_lkr': new_revenue,
                        'last_updated': firestore.SERVER_TIMESTAMP
                    })
                else:
                    transaction.set(log_ref, {
                        'date': today_str,
                        'bus_id': bus_id,
                        'total_passengers': headcount_increase,
                        'total_revenue_lkr': revenue_increase,
                        'created_at': firestore.SERVER_TIMESTAMP,
                        'last_updated': firestore.SERVER_TIMESTAMP
                    })

            transaction = self.db.transaction()
            update_in_transaction(transaction, log_ref)
            print(f"🚌 {bus_id}: +{headcount_increase} Passengers | +{revenue_increase} LKR | Log: {today_str}")

        except Exception as e:
            print(f"❌ Transaction failed: {e}")

# If run as a standalone script, it acts as a test simulator
if __name__ == '__main__':
    print("--- Revenue Engine Test Mode ---")
    print("Normally, your YOLOv11 script will import this class.")
    print("Simulating 3 passengers entering bus_001...")
    
    engine = RevenueEngine()
    engine.process_new_passengers(bus_id="bus_001", headcount_increase=3)
    
    time.sleep(2)
    print("Simulating 2 more passengers entering...")
    engine.process_new_passengers(bus_id="bus_001", headcount_increase=2)
    print("Test complete!")
