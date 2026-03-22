from utils.firebase_config import db
from models.schemas import DashboardSummaryResponse, RevenueSummaryData, RecentTripItem, BestWorstTrip, AIRecommendation, YieldAlert
from datetime import datetime

class RevenueService:
    @staticmethod
    def get_dashboard_summary() -> DashboardSummaryResponse:
        docs = db.collection('trips').order_by('actualEndTime', direction='DESCENDING').limit(30).stream()
        
        today_str = datetime.now().strftime('%Y-%m-%d')
        
        revenue_today = 0.0
        profit_today = 0.0
        leakage_today = 0.0
        trips_today = 0
        total_ai_passengers = 0
        total_tickets_sold = 0
        total_unpaid_or_leaked = 0

        recent_trips = []
        recent_evening_trips = []

        best_profit = -float('inf')
        worst_profit = float('inf')
        best_trip = None
        worst_trip = None

        for doc in docs:
            data = doc.to_dict()
            date = data.get('date', '')
            trip_type = data.get('tripType', '').upper()
            ai_passengers = int(data.get('aiPassengerCount', 0))
            tickets_sold = int(data.get('soldTicketCount', 0))
            
            unpaid_or_leaked = max(ai_passengers - tickets_sold, 0)
            
            actual_revenue = float(data.get('actualRevenue', 0))
            operating_cost = 4000.0  # Fixed based on constraints
            profit_or_loss = actual_revenue - operating_cost
            
            # Today's Math
            if date == today_str:
                revenue_today += actual_revenue
                profit_today += profit_or_loss
                trips_today += 1
                
                # Daily leakage sum
                avg_rev_per_ticket = actual_revenue / tickets_sold if tickets_sold > 0 else 75
                leakage_today += (unpaid_or_leaked * avg_rev_per_ticket)

            total_ai_passengers += ai_passengers
            total_tickets_sold += tickets_sold
            total_unpaid_or_leaked += unpaid_or_leaked

            # Identify Best / Worst
            if profit_or_loss > best_profit:
                best_profit = profit_or_loss
                best_trip = BestWorstTrip(
                    trip_type=trip_type,
                    profit_or_loss=profit_or_loss,
                    label="+" + str(int(profit_or_loss)) if profit_or_loss >= 0 else str(int(profit_or_loss))
                )
            if profit_or_loss < worst_profit:
                worst_profit = profit_or_loss
                worst_trip = BestWorstTrip(
                    trip_type=trip_type,
                    profit_or_loss=profit_or_loss,
                    label="+" + str(int(profit_or_loss)) if profit_or_loss >= 0 else str(int(profit_or_loss))
                )

            # Evening Alert Tracking
            if trip_type == 'EVENING' and len(recent_evening_trips) < 5:
                recent_evening_trips.append({'revenue': actual_revenue, 'loss': profit_or_loss})

            # Assemble Recent Trip List
            is_warning = profit_or_loss < 0 or unpaid_or_leaked > 5
            
            recent_trips.append(RecentTripItem(
                date=date,
                trip_type=trip_type,
                ai_passengers=ai_passengers,
                tickets_sold=tickets_sold,
                unpaid_or_leaked=unpaid_or_leaked,
                actual_revenue=actual_revenue,
                operating_cost=operating_cost,
                profit_or_loss=profit_or_loss,
                is_profit=profit_or_loss >= 0,
                is_warning=is_warning
            ))

        # Alert Logic calculations
        evening_losses = [t for t in recent_evening_trips if t['loss'] < 0]
        evening_len = len(recent_evening_trips)
        
        sum_evening_rev = sum(t['revenue'] for t in recent_evening_trips)
        sum_evening_loss = sum(t['loss'] for t in recent_evening_trips)
        
        avg_evening_rev = sum_evening_rev / evening_len if evening_len > 0 else 0
        avg_evening_loss = sum_evening_loss / evening_len if evening_len > 0 else 0

        # AI Recommendations
        is_evening_critical = len(evening_losses) >= 3 or avg_evening_loss < -1000
        
        reasons = []
        if len(evening_losses) >= 3:
            reasons.append(f"{len(evening_losses)} consecutive evening losses detected")
        if avg_evening_loss < -1000:
            reasons.append("Average evening losses exceed acceptable threshold")
        if not reasons:
            reasons.append("Demand appears stable across both time blocks")
            
        rec = AIRecommendation(
            morning_action="Keep running",
            evening_action="Cancel temp. / Review" if is_evening_critical else "Monitor closely",
            confidence="High" if evening_len >= 3 else "Medium",
            reason_points=reasons
        )

        # Low Demand Alert
        alert = None
        if is_evening_critical:
            alert = YieldAlert(
                title="Low Demand Alert",
                last_n_evening_trips=evening_len,
                avg_revenue=avg_evening_rev,
                fixed_cost=4000.0,
                avg_loss=avg_evening_loss,
                recommendation="Consider cancelling evening trips temporarily",
                severity="HIGH" if len(evening_losses) >= 4 else "MEDIUM"
            )

        # Totals
        overall_leakage_rate = (total_unpaid_or_leaked / total_ai_passengers * 100) if total_ai_passengers > 0 else 0.0
        ticket_leakage_percent = (total_unpaid_or_leaked / total_ai_passengers * 100) if total_ai_passengers > 0 else 0.0

        return DashboardSummaryResponse(
            summary_data=RevenueSummaryData(
                revenue_today=revenue_today,
                net_profit_today=profit_today,
                ticket_leakage_amount=leakage_today,
                ticket_leakage_percent=ticket_leakage_percent,
                trips_done_today=trips_today,
                total_ai_passengers=total_ai_passengers,
                total_tickets_sold=total_tickets_sold,
                total_unpaid_or_leaked=total_unpaid_or_leaked,
                overall_leakage_rate=overall_leakage_rate
            ),
            ai_recommendation=rec,
            low_demand_alert=alert,
            best_trip=best_trip,
            worst_trip=worst_trip,
            recent_trips=recent_trips[:15] # Send only the latest 15 to keep UI render fast
        )
