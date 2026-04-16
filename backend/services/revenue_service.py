import csv
from collections import defaultdict
from datetime import datetime, timedelta
from io import StringIO

from utils.firebase_config import db
from models.schemas import (
    DashboardSummaryResponse,
    RevenueSummaryData,
    RecentTripItem,
    BestWorstTrip,
    AIRecommendation,
    YieldAlert,
    SelectedRangeInfo,
    DailyTrendPoint,
    PercentageInsight,
    ReportSummary,
    ComparisonContext,
)

class RevenueService:
    @staticmethod
    def _completed_docs(docs):
        completed = []
        for doc in docs:
            data = doc.to_dict() or {}
            if str(data.get("status", "completed")).lower() != "completed":
                continue
            completed.append(doc)
        return completed

    @staticmethod
    def _today_date():
        return datetime.now().date()

    @staticmethod
    def _safe_date(value: str | None):
        if not value:
            return None
        try:
            return datetime.strptime(value, "%Y-%m-%d").date()
        except ValueError:
            return None

    @staticmethod
    def _resolve_range(range_preset: str = "today", start_date: str | None = None, end_date: str | None = None):
        today = RevenueService._today_date()
        preset = (range_preset or "today").lower()

        if preset == "last7":
            start = today - timedelta(days=6)
            end = today
            label = "Last 7 Days"
        elif preset == "last30":
            start = today - timedelta(days=29)
            end = today
            label = "Last 30 Days"
        elif preset == "custom":
            parsed_start = RevenueService._safe_date(start_date) or today
            parsed_end = RevenueService._safe_date(end_date) or parsed_start
            start = min(parsed_start, parsed_end)
            end = max(parsed_start, parsed_end)
            label = f"{start.isoformat()} to {end.isoformat()}"
        else:
            preset = "today"
            start = today
            end = today
            label = "Today"

        return SelectedRangeInfo(
            preset=preset,
            start_date=start.isoformat(),
            end_date=end.isoformat(),
            label=label,
        )

    @staticmethod
    def _query_trip_docs(selected_range: SelectedRangeInfo):
        if db is None:
            return []

        try:
            query = (
                db.collection('trips')
                .where('date', '>=', selected_range.start_date)
                .where('date', '<=', selected_range.end_date)
                .order_by('date', direction='ASCENDING')
            )
            return list(query.stream())
        except Exception:
            return []

    @staticmethod
    def _query_trip_docs_between(start_date: str, end_date: str):
        if db is None:
            return []

        try:
            query = (
                db.collection('trips')
                .where('date', '>=', start_date)
                .where('date', '<=', end_date)
                .order_by('date', direction='ASCENDING')
            )
            return list(query.stream())
        except Exception:
            return []

    @staticmethod
    def _empty_response() -> DashboardSummaryResponse:
        selected_range = RevenueService._resolve_range()
        return DashboardSummaryResponse(
            summary_data=RevenueSummaryData(
                revenue_today=0.0,
                net_profit_today=0.0,
                ticket_leakage_amount=0.0,
                ticket_leakage_percent=0.0,
                trips_done_today=0,
                total_ai_passengers=0,
                total_tickets_sold=0,
                total_unpaid_or_leaked=0,
                overall_leakage_rate=0.0
            ),
            ai_recommendation=AIRecommendation(
                morning_action="Keep running",
                evening_action="Monitor closely",
                confidence="Low",
                reason_points=["No completed trip data available yet"]
            ),
            low_demand_alert=None,
            best_trip=None,
            worst_trip=None,
            recent_trips=[],
            selected_range=selected_range,
            daily_trends=[],
            percentage_insight=PercentageInsight(
                paid_percentage=0.0,
                unpaid_percentage=0.0,
                profitable_trip_percentage=0.0,
                morning_success_percentage=0.0,
                evening_success_percentage=0.0,
            ),
            report_summary=ReportSummary(
                trip_count=0,
                tickets_sold=0,
                ai_passengers=0,
                unpaid_or_leaked=0,
                leakage_percentage=0.0,
                total_revenue=0.0,
                total_profit_or_loss=0.0,
                low_demand_trip_count=0,
                key_recommendation="No completed trip data available yet",
            ),
            comparison_context=ComparisonContext(
                reference_window_label="Reference window: last 7 completed days",
                average_daily_tickets=0.0,
                average_daily_revenue=0.0,
                average_daily_profit=0.0,
                average_daily_leakage_percent=0.0,
                average_daily_trips=0.0,
                selected_period_tickets_delta_percent=0.0,
                selected_period_revenue_delta_percent=0.0,
                selected_period_profit_delta_percent=0.0,
                benchmark_daily_trends=[],
            )
        )

    @staticmethod
    def _safe_int(value, default=0):
        try:
            return int(value)
        except (TypeError, ValueError):
            return default

    @staticmethod
    def _safe_float(value, default=0.0):
        try:
            return float(value)
        except (TypeError, ValueError):
            return default

    @staticmethod
    def _resolve_ai_passengers(data):
        return RevenueService._safe_int(
            data.get(
                'aiPassengerCount',
                data.get('finalEstimatedPassengerCount', data.get('estimatedPassengerCount', 0)),
            ),
            0,
        )

    @staticmethod
    def _normalize_trip_metrics(ai_passengers, tickets_sold, revenue):
        ai_count = max(RevenueService._safe_int(ai_passengers, 0), 0)
        sold_count = max(RevenueService._safe_int(tickets_sold, 0), 0)
        actual_revenue = max(RevenueService._safe_float(revenue, 0.0), 0.0)

        # Demo and dashboard metrics must stay logically consistent.
        if ai_count == 0:
            return 0, 0, 0.0

        if sold_count > ai_count:
            sold_count = ai_count

        if sold_count == 0:
            actual_revenue = 0.0

        return ai_count, sold_count, actual_revenue

    @staticmethod
    def _bucket_start_for_today(raw_start: str, trip_type: str):
        try:
            start_dt = datetime.fromisoformat(raw_start)
            minute_bucket = 30 if start_dt.minute >= 30 else 0
            bucket_start = start_dt.replace(minute=minute_bucket, second=0, microsecond=0)
            return bucket_start.strftime("%Y-%m-%d %H:%M"), bucket_start.strftime("%H:%M")
        except ValueError:
            fallback_hour = "07:00" if trip_type == "MORNING" else "17:30" if trip_type == "EVENING" else "12:00"
            return fallback_hour, fallback_hour

    @staticmethod
    def _build_daily_trends(docs, selected_range: SelectedRangeInfo | None = None):
        group_by_hour = selected_range is not None and selected_range.preset == "today"
        grouped = defaultdict(lambda: {
            'tickets_sold': 0,
            'revenue': 0.0,
            'ai_passengers': 0,
            'unpaid_or_leaked': 0,
            'profitable_trips': 0,
            'total_trips': 0,
            'morning_total': 0,
            'morning_profitable': 0,
            'evening_total': 0,
            'evening_profitable': 0,
            'label': '',
            'sort_key': '',
        })

        for doc in docs:
            data = doc.to_dict() or {}
            date = str(data.get('date', ''))
            if not date:
                continue

            trip_type = str(data.get('tripType', '')).upper()
            ai_passengers, tickets_sold, revenue = RevenueService._normalize_trip_metrics(
                RevenueService._resolve_ai_passengers(data),
                data.get('soldTicketCount', 0),
                data.get('actualRevenue', 0),
            )
            unpaid = max(ai_passengers - tickets_sold, 0)
            profit = revenue - 4000.0

            if group_by_hour:
                raw_start = str(data.get('actualStartTime', ''))
                group_key, label = RevenueService._bucket_start_for_today(raw_start, trip_type)
            else:
                group_key = date
                label = date[5:]

            bucket = grouped[group_key]
            bucket['label'] = label
            bucket['sort_key'] = group_key
            bucket['tickets_sold'] += tickets_sold
            bucket['revenue'] += revenue
            bucket['ai_passengers'] += ai_passengers
            bucket['unpaid_or_leaked'] += unpaid
            bucket['total_trips'] += 1
            if profit >= 0:
                bucket['profitable_trips'] += 1
            if trip_type == 'MORNING':
                bucket['morning_total'] += 1
                if profit >= 0:
                    bucket['morning_profitable'] += 1
            if trip_type == 'EVENING':
                bucket['evening_total'] += 1
                if profit >= 0:
                    bucket['evening_profitable'] += 1

        trends = []
        for group_key in sorted(grouped.keys()):
            bucket = grouped[group_key]
            ai_passengers = bucket['ai_passengers']
            leakage_percent = (bucket['unpaid_or_leaked'] / ai_passengers * 100) if ai_passengers > 0 else 0.0
            trends.append(
                DailyTrendPoint(
                    date=group_key,
                    label=bucket['label'],
                    tickets_sold=bucket['tickets_sold'],
                    revenue=bucket['revenue'],
                    ai_passengers=ai_passengers,
                    unpaid_or_leaked=bucket['unpaid_or_leaked'],
                    leakage_percent=leakage_percent,
                    profitable_trips=bucket['profitable_trips'],
                    total_trips=bucket['total_trips'],
                    morning_total=bucket['morning_total'],
                    morning_profitable=bucket['morning_profitable'],
                    evening_total=bucket['evening_total'],
                    evening_profitable=bucket['evening_profitable'],
                )
            )
        return trends

    @staticmethod
    def _build_recommendation_and_alert(recent_evening_trips):
        evening_losses = [t for t in recent_evening_trips if t['loss'] < 0]
        evening_len = len(recent_evening_trips)

        sum_evening_rev = sum(t['revenue'] for t in recent_evening_trips)
        sum_evening_loss = sum(t['loss'] for t in recent_evening_trips)

        avg_evening_rev = sum_evening_rev / evening_len if evening_len > 0 else 0.0
        avg_evening_loss = sum_evening_loss / evening_len if evening_len > 0 else 0.0

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

        return rec, alert

    @staticmethod
    def _build_comparison_context(selected_range: SelectedRangeInfo, selected_daily_trends, summary_data: RevenueSummaryData):
        start = RevenueService._safe_date(selected_range.start_date)
        if start is None:
            return ComparisonContext(
                reference_window_label="Reference window: last 7 completed days",
                average_daily_tickets=0.0,
                average_daily_revenue=0.0,
                average_daily_profit=0.0,
                average_daily_leakage_percent=0.0,
                average_daily_trips=0.0,
                selected_period_tickets_delta_percent=0.0,
                selected_period_revenue_delta_percent=0.0,
                selected_period_profit_delta_percent=0.0,
                benchmark_daily_trends=[],
            )

        benchmark_end = start - timedelta(days=1)
        benchmark_start = benchmark_end - timedelta(days=6)
        if benchmark_end < benchmark_start:
            benchmark_start = benchmark_end

        benchmark_docs = RevenueService._completed_docs(
            RevenueService._query_trip_docs_between(
                benchmark_start.isoformat(),
                benchmark_end.isoformat(),
            )
        ) if benchmark_end >= benchmark_start else []

        benchmark_daily_trends = RevenueService._build_daily_trends(benchmark_docs)
        benchmark_days = len(benchmark_daily_trends)

        if benchmark_days == 0:
            return ComparisonContext(
                reference_window_label="Reference window: last 7 completed days",
                average_daily_tickets=0.0,
                average_daily_revenue=0.0,
                average_daily_profit=0.0,
                average_daily_leakage_percent=0.0,
                average_daily_trips=0.0,
                selected_period_tickets_delta_percent=0.0,
                selected_period_revenue_delta_percent=0.0,
                selected_period_profit_delta_percent=0.0,
                benchmark_daily_trends=[],
            )

        average_daily_tickets = sum(point.tickets_sold for point in benchmark_daily_trends) / benchmark_days
        average_daily_revenue = sum(point.revenue for point in benchmark_daily_trends) / benchmark_days
        average_daily_profit = sum(point.revenue - (point.total_trips * 4000.0) for point in benchmark_daily_trends) / benchmark_days
        average_daily_leakage_percent = sum(point.leakage_percent for point in benchmark_daily_trends) / benchmark_days
        average_daily_trips = sum(point.total_trips for point in benchmark_daily_trends) / benchmark_days

        selected_days = 1 if selected_range.preset == "today" else max(len(selected_daily_trends), 1)
        selected_avg_tickets = summary_data.total_tickets_sold / selected_days
        selected_avg_revenue = summary_data.revenue_today / selected_days
        selected_avg_profit = summary_data.net_profit_today / selected_days

        tickets_delta = ((selected_avg_tickets - average_daily_tickets) / average_daily_tickets * 100) if average_daily_tickets > 0 else 0.0
        revenue_delta = ((selected_avg_revenue - average_daily_revenue) / average_daily_revenue * 100) if average_daily_revenue > 0 else 0.0
        profit_delta = ((selected_avg_profit - average_daily_profit) / abs(average_daily_profit) * 100) if average_daily_profit != 0 else 0.0

        return ComparisonContext(
            reference_window_label="Reference window: last 7 completed days",
            average_daily_tickets=average_daily_tickets,
            average_daily_revenue=average_daily_revenue,
            average_daily_profit=average_daily_profit,
            average_daily_leakage_percent=average_daily_leakage_percent,
            average_daily_trips=average_daily_trips,
            selected_period_tickets_delta_percent=tickets_delta,
            selected_period_revenue_delta_percent=revenue_delta,
            selected_period_profit_delta_percent=profit_delta,
            benchmark_daily_trends=benchmark_daily_trends,
        )

    @staticmethod
    def get_dashboard_summary(range_preset: str = "today", start_date: str | None = None, end_date: str | None = None) -> DashboardSummaryResponse:
        if db is None:
            return RevenueService._empty_response()

        selected_range = RevenueService._resolve_range(range_preset, start_date, end_date)
        docs = RevenueService._completed_docs(RevenueService._query_trip_docs(selected_range))
        if not docs:
            empty = RevenueService._empty_response()
            empty.selected_range = selected_range
            empty.comparison_context = RevenueService._build_comparison_context(
                selected_range,
                [],
                empty.summary_data,
            )
            return empty

        revenue_today = 0.0
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
            data = doc.to_dict() or {}
            date = str(data.get('date', ''))
            trip_type = str(data.get('tripType', '')).upper()
            ai_passengers, tickets_sold, actual_revenue = RevenueService._normalize_trip_metrics(
                RevenueService._resolve_ai_passengers(data),
                data.get('soldTicketCount', 0),
                data.get('actualRevenue', 0),
            )

            # Dashboard integrity metrics come from finalized trips only.
            # This keeps PP2 demo data consistent after end-trip is completed.
            unpaid_or_leaked = max(ai_passengers - tickets_sold, 0)

            operating_cost = 4000.0
            profit_or_loss = actual_revenue - operating_cost

            revenue_today += actual_revenue
            trips_today += 1
            avg_rev_per_ticket = actual_revenue / tickets_sold if tickets_sold > 0 else 75.0
            leakage_today += unpaid_or_leaked * avg_rev_per_ticket

            total_ai_passengers += ai_passengers
            total_tickets_sold += tickets_sold
            total_unpaid_or_leaked += unpaid_or_leaked

            if profit_or_loss > best_profit:
                best_profit = profit_or_loss
                best_trip = BestWorstTrip(
                    trip_type=trip_type or "N/A",
                    profit_or_loss=profit_or_loss,
                    label="+" + str(int(profit_or_loss)) if profit_or_loss >= 0 else str(int(profit_or_loss))
                )
            if profit_or_loss < worst_profit:
                worst_profit = profit_or_loss
                worst_trip = BestWorstTrip(
                    trip_type=trip_type or "N/A",
                    profit_or_loss=profit_or_loss,
                    label="+" + str(int(profit_or_loss)) if profit_or_loss >= 0 else str(int(profit_or_loss))
                )

            if trip_type == 'EVENING' and len(recent_evening_trips) < 5:
                recent_evening_trips.append({'revenue': actual_revenue, 'loss': profit_or_loss})

            is_warning = profit_or_loss < 0 or unpaid_or_leaked > 0
            recent_trips.append(RecentTripItem(
                date=date or "N/A",
                trip_type=trip_type or "N/A",
                ai_passengers=ai_passengers,
                tickets_sold=tickets_sold,
                unpaid_or_leaked=unpaid_or_leaked,
                actual_revenue=actual_revenue,
                operating_cost=operating_cost,
                profit_or_loss=profit_or_loss,
                is_profit=profit_or_loss >= 0,
                is_warning=is_warning
            ))

        rec, alert = RevenueService._build_recommendation_and_alert(recent_evening_trips)
        daily_trends = RevenueService._build_daily_trends(docs, selected_range)

        net_profit_today = revenue_today - (trips_today * 4000.0)
        overall_leakage_rate = (total_unpaid_or_leaked / total_ai_passengers * 100) if total_ai_passengers > 0 else 0.0
        ticket_leakage_percent = overall_leakage_rate
        profitable_trip_percentage = (sum(1 for trip in recent_trips if trip.is_profit) / trips_today * 100) if trips_today > 0 else 0.0

        morning_total = sum(point.morning_total for point in daily_trends)
        morning_profitable = sum(point.morning_profitable for point in daily_trends)
        evening_total = sum(point.evening_total for point in daily_trends)
        evening_profitable = sum(point.evening_profitable for point in daily_trends)

        if total_ai_passengers > 0:
            paid_percentage = max(0.0, min((total_tickets_sold / total_ai_passengers * 100), 100.0))
            unpaid_percentage = max(0.0, 100.0 - paid_percentage)
        else:
            paid_percentage = 0.0
            unpaid_percentage = 0.0

        percentage_insight = PercentageInsight(
            paid_percentage=paid_percentage,
            unpaid_percentage=unpaid_percentage,
            profitable_trip_percentage=profitable_trip_percentage,
            morning_success_percentage=(morning_profitable / morning_total * 100) if morning_total > 0 else 0.0,
            evening_success_percentage=(evening_profitable / evening_total * 100) if evening_total > 0 else 0.0,
        )

        low_demand_trip_count = sum(1 for trip in recent_trips if trip.profit_or_loss < 0)
        report_summary = ReportSummary(
            trip_count=trips_today,
            tickets_sold=total_tickets_sold,
            ai_passengers=total_ai_passengers,
            unpaid_or_leaked=total_unpaid_or_leaked,
            leakage_percentage=overall_leakage_rate,
            total_revenue=revenue_today,
            total_profit_or_loss=net_profit_today,
            low_demand_trip_count=low_demand_trip_count,
            key_recommendation=rec.evening_action,
        )
        summary_data = RevenueSummaryData(
            revenue_today=revenue_today,
            net_profit_today=net_profit_today,
            ticket_leakage_amount=leakage_today,
            ticket_leakage_percent=ticket_leakage_percent,
            trips_done_today=trips_today,
            total_ai_passengers=total_ai_passengers,
            total_tickets_sold=total_tickets_sold,
            total_unpaid_or_leaked=total_unpaid_or_leaked,
            overall_leakage_rate=overall_leakage_rate
        )
        comparison_context = RevenueService._build_comparison_context(
            selected_range,
            daily_trends,
            summary_data,
        )

        return DashboardSummaryResponse(
            summary_data=summary_data,
            ai_recommendation=rec,
            low_demand_alert=alert,
            best_trip=best_trip,
            worst_trip=worst_trip,
            recent_trips=list(reversed(recent_trips))[:15],
            selected_range=selected_range,
            daily_trends=daily_trends,
            percentage_insight=percentage_insight,
            report_summary=report_summary,
            comparison_context=comparison_context,
        )

    @staticmethod
    def build_revenue_report_csv(range_preset: str = "today", start_date: str | None = None, end_date: str | None = None):
        summary = RevenueService.get_dashboard_summary(range_preset, start_date, end_date)
        selected_range = summary.selected_range
        docs = RevenueService._completed_docs(RevenueService._query_trip_docs(selected_range))
        trip_rows = []
        morning_profit = 0.0
        evening_profit = 0.0
        morning_count = 0
        evening_count = 0
        below_break_even = 0
        output = StringIO()
        writer = csv.writer(output)

        writer.writerow(["Smart Shuttle Revenue Report"])
        writer.writerow(["Generated At", datetime.now().isoformat(timespec="seconds")])
        writer.writerow(["Selected Preset", selected_range.preset])
        writer.writerow(["Selected Range", selected_range.label])
        writer.writerow(["Start Date", selected_range.start_date])
        writer.writerow(["End Date", selected_range.end_date])
        writer.writerow([])
        writer.writerow(["Benchmark Window", summary.comparison_context.reference_window_label])
        writer.writerow(["Average Daily Revenue", f"{summary.comparison_context.average_daily_revenue:.2f}"])
        writer.writerow(["Average Daily Profit", f"{summary.comparison_context.average_daily_profit:.2f}"])
        writer.writerow(["Profitable Trip Percentage", f"{summary.percentage_insight.profitable_trip_percentage:.2f}%"])
        writer.writerow(["Morning Success Percentage", f"{summary.percentage_insight.morning_success_percentage:.2f}%"])
        writer.writerow(["Evening Success Percentage", f"{summary.percentage_insight.evening_success_percentage:.2f}%"])
        writer.writerow([])
        writer.writerow(["Summary Metrics"])
        writer.writerow(["Trip Count", summary.report_summary.trip_count])
        writer.writerow(["Tickets Sold", summary.report_summary.tickets_sold])
        writer.writerow(["AI Passengers", summary.report_summary.ai_passengers])
        writer.writerow(["Unpaid / Leaked", summary.report_summary.unpaid_or_leaked])
        writer.writerow(["Leakage Percentage", f"{summary.report_summary.leakage_percentage:.2f}%"])
        writer.writerow(["Total Revenue", f"{summary.report_summary.total_revenue:.2f}"])
        writer.writerow(["Total Profit/Loss", f"{summary.report_summary.total_profit_or_loss:.2f}"])
        writer.writerow(["Low-demand Trip Count", summary.report_summary.low_demand_trip_count])
        writer.writerow(["Key Recommendation", summary.report_summary.key_recommendation])
        writer.writerow([])
        writer.writerow(["Trend Breakdown"])
        writer.writerow([
            "Date",
            "Tickets Sold",
            "Revenue",
            "AI Passengers",
            "Unpaid / Leaked",
            "Leakage %",
            "Profitable Trips",
            "Total Trips",
        ])

        for point in summary.daily_trends:
            writer.writerow([
                point.date,
                point.tickets_sold,
                f"{point.revenue:.2f}",
                point.ai_passengers,
                point.unpaid_or_leaked,
                f"{point.leakage_percent:.2f}",
                point.profitable_trips,
                point.total_trips,
            ])

        writer.writerow([])
        writer.writerow(["Trip-Level Breakdown"])
        writer.writerow([
            "Date",
            "Trip Type",
            "AI Passengers",
            "Tickets Sold",
            "Unpaid / Leaked",
            "Actual Revenue",
            "Profit / Loss",
            "Leakage %",
            "Status",
            "Day Profile",
        ])

        for doc in docs:
            data = doc.to_dict() or {}
            ai_passengers, tickets_sold, actual_revenue = RevenueService._normalize_trip_metrics(
                RevenueService._resolve_ai_passengers(data),
                data.get('soldTicketCount', 0),
                data.get('actualRevenue', 0),
            )
            unpaid = max(ai_passengers - tickets_sold, 0)
            leakage_percent = (unpaid / ai_passengers * 100) if ai_passengers > 0 else 0.0
            profit_or_loss = actual_revenue - 4000.0
            trip_type = str(data.get('tripType', ''))
            status = "Profit" if profit_or_loss >= 0 else "Loss"
            trip_rows.append([
                data.get('date', ''),
                trip_type,
                ai_passengers,
                tickets_sold,
                unpaid,
                f"{actual_revenue:.2f}",
                f"{profit_or_loss:.2f}",
                f"{leakage_percent:.2f}",
                status,
                data.get('dayProfile', ''),
            ])

            if profit_or_loss < 0:
                below_break_even += 1
            if trip_type.upper() == "MORNING":
                morning_count += 1
                morning_profit += profit_or_loss
            elif trip_type.upper() == "EVENING":
                evening_count += 1
                evening_profit += profit_or_loss

        for row in trip_rows:
            writer.writerow(row)

        writer.writerow([])
        writer.writerow(["Insights"])
        if evening_count > 0 and evening_profit < 0:
            writer.writerow(["Evening trips are causing consistent losses across the selected range."])
        if morning_count > 0 and morning_profit > 0:
            writer.writerow([f"Morning trips contribute {morning_profit:.2f} total profit in this report."])
        writer.writerow([f"{below_break_even} out of {len(trip_rows)} trips are below break-even."])
        writer.writerow([summary.report_summary.key_recommendation])

        filename = f"revenue_report_{selected_range.start_date}_to_{selected_range.end_date}.csv"
        return output.getvalue(), filename
