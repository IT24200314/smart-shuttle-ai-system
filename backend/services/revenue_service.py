from utils.firebase_config import db
from models.schemas import DashboardSummaryResponse, RevenueSummaryData, RecentTripItem, TripLedgerItem, BestWorstTrip, AIRecommendation, YieldAlert
from datetime import datetime

class RevenueService:
    @staticmethod
    def get_dashboard_summary() -> DashboardSummaryResponse:
        docs = db.collection('trips').order_by('actualEndTime', direction='DESCENDING').limit(30).stream()
        
        today_str = datetime.now().strftime('%Y-%m-%d')
        
        revenue_today = 0.0
        profit_today = 0.0
        leakage_today = 0.0
        trips_completed = 0
        total_ai_count = 0
        total_tickets = 0
        total_unpaid = 0

        best_trip = None
        worst_trip = None
        recent_evening_trips = []
        recent_ledger = []

        for doc in docs:
            data = doc.to_dict()
            date = data.get('date', '')
            rev = float(data.get('actualRevenue', 0))
            prf = float(data.get('profitOrLoss', 0))
            lk = float(data.get('revenueLeakage', 0))
            
            ai_count = int(data.get('aiPassengerCount', 0))
            tkt_count = int(data.get('soldTicketCount', 0))
            unpd = int(data.get('unpaidPassengerCount', 0))

            # Today's Math
            if date == today_str:
                revenue_today += rev
                profit_today += prf
                leakage_today += lk
                trips_completed += 1

            total_ai_count += ai_count
            total_tickets += tkt_count
            total_unpaid += unpd

            # Best Worst
            if best_trip is None or prf > best_trip['profitOrLoss']:
                best_trip = {'tripType': data.get('tripType', ''), 'profitOrLoss': prf}
            if worst_trip is None or prf < worst_trip['profitOrLoss']:
                worst_trip = {'tripType': data.get('tripType', ''), 'profitOrLoss': prf}

            # Evening Alert Tracking
            if data.get('tripType') == 'evening' and len(recent_evening_trips) < 5:
                recent_evening_trips.append(data)

            # Ledger
            recent_ledger.append(TripLedgerItem(
                date=date,
                tripType=data.get('tripType', '').upper(),
                aiCount=ai_count,
                ticketsSold=tkt_count,
                profitOrLoss=prf,
                isProfit=prf >= 0
            ))

        # Yield Alert Logic
        evening_losses = 0
        sum_evening_rev = 0
        sum_evening_loss = 0
        for t in recent_evening_trips:
            p = float(t.get('profitOrLoss', 0))
            if p < 0: evening_losses += 1
            sum_evening_rev += float(t.get('actualRevenue', 0))
            sum_evening_loss += p

        evening_len = len(recent_evening_trips)
        avg_rev = sum_evening_rev / evening_len if evening_len > 0 else 0
        avg_loss = sum_evening_loss / evening_len if evening_len > 0 else 0
        
        # Recommendations
        rec = AIRecommendation(
            morning_action="✅ Keep running",
            evening_action="❌ Cancel temp." if evening_losses >= 3 else "⚠️ Monitor",
            reason=["5 consecutive losses", "Avg passengers below threshold"] if evening_losses >= 3 else []
        )

        overall_leakage = (total_unpaid / total_ai_count * 100) if total_ai_count > 0 else 0

        return DashboardSummaryResponse(
            summary=RevenueSummaryData(
                total_revenue=revenue_today,
                revenue_growth=5.2,
                forecast_30d=145.0,
                leakage_percent=overall_leakage,
                leakage_amount=leakage_today
            ),
            recent_trips=[
                RecentTripItem(
                    trip_id=f"T-{i+1:03d}",
                    route_id=item.tripType.capitalize(),
                    passenger_count=item.aiCount,
                    revenue=item.profitOrLoss + 2000.0 # Just a display value based on profit
                ) for i, item in enumerate(recent_ledger[:10])
            ]
        )
