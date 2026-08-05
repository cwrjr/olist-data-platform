import streamlit as st
import pandas as pd
import numpy as np
import pydeck as pdk
import plotly.express as px
import plotly.graph_objects as go
import os
from databricks import sql

# Set up page configurations
st.set_page_config(
    page_title="Olist Logistics Optimizer",
    page_icon="🚚",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Dark-themed custom styles
st.markdown("""
<style>
    .reportview-container {
        background: #0f1115;
    }
    div[data-testid="stMetricValue"] {
        font-size: 2rem;
        font-weight: 700;
        color: #00ffcc !important;
    }
    div[data-testid="stMetricLabel"] {
        font-size: 0.95rem;
        color: #8f9aa9;
    }
    .metric-card {
        background-color: #1a1e24;
        border: 1px solid #2d3139;
        border-radius: 10px;
        padding: 15px;
        margin-bottom: 10px;
    }
    h1, h2, h3 {
        font-family: 'Outfit', 'Inter', sans-serif !important;
    }
</style>
""", unsafe_allow_html=True)

# Databricks SQL Client Connection
@st.cache_data(ttl=600)
def load_optimizer_data():
    DATABRICKS_HOST = os.environ.get("DATABRICKS_HOST")
    DATABRICKS_TOKEN = os.environ.get("DATABRICKS_TOKEN")
    
    if not DATABRICKS_HOST or not DATABRICKS_TOKEN:
        st.error("Missing Databricks host/token secrets. Please configure them in your .env file.")
        return pd.DataFrame(), pd.DataFrame()
        
    try:
        conn = sql.connect(
            server_hostname=DATABRICKS_HOST,
            http_path="/sql/1.0/warehouses/d47b8b9ee1830b6a",
            access_token=DATABRICKS_TOKEN
        )
        
        cursor = conn.cursor()
        
        # 1. Fetch Executive ROI Simulation overview
        cursor.execute("SELECT * FROM olist.dev.gold_executive_overview")
        cols_exec = [c[0] for c in cursor.description]
        df_exec = pd.DataFrame(cursor.fetchall(), columns=cols_exec)
        
        # 2. Fetch Spatial Routing data
        cursor.execute("SELECT * FROM olist.dev.gold_spatial_routing")
        cols_spatial = [c[0] for c in cursor.description]
        df_spatial = pd.DataFrame(cursor.fetchall(), columns=cols_spatial)
        
        cursor.close()
        conn.close()
        return df_exec, df_spatial
        
    except Exception as e:
        st.error(f"Failed to connect to Databricks SQL Warehouse: {e}")
        return pd.DataFrame(), pd.DataFrame()

# Load datasets
df_exec, df_spatial = load_optimizer_data()

# Convert all spatial coordinates to standard float64 to avoid serialization errors in Pydeck (which fallback to [0,0])
if not df_spatial.empty:
    for col in ["seller_lat", "seller_lon", "customer_lat", "customer_lon", "hub_lat", "hub_lon"]:
        df_spatial[col] = pd.to_numeric(df_spatial[col], errors="coerce")


# ----------------- SIDEBAR CONTROLS -----------------
st.sidebar.title("🚚 Scenario Controls")
st.sidebar.markdown("---")

# Scenario Selection Mode
scenario_mode = st.sidebar.radio(
    "Choose Logistics Mode:",
    ["Baseline Routes", "Optimized Hubs", "Side-by-Side Comparison"]
)

# Filters
st.sidebar.markdown("### Interactive Filters")

if not df_exec.empty:
    states_list = sorted(list(df_exec["customer_state"].dropna().unique()))
    selected_states = st.sidebar.multiselect(
        "Filter by Customer State:",
        states_list,
        default=states_list[:5] if len(states_list) > 5 else states_list
    )
    
    max_days_allowed = st.sidebar.slider(
        "Max Allowed Transit Time (Days):",
        min_value=1,
        max_value=45,
        value=30
    )
else:
    selected_states = []
    max_days_allowed = 30

# Apply Filters
if not df_exec.empty:
    filtered_exec = df_exec[
        (df_exec["customer_state"].isin(selected_states)) &
        (df_exec["optimized_shipping_days"] <= max_days_allowed)
    ]
    
    # Filter spatial routes corresponding to those orders
    filtered_spatial = df_spatial[
        df_spatial["customer_state"].isin(selected_states)
    ]
else:
    filtered_exec = pd.DataFrame()
    filtered_spatial = pd.DataFrame()

# ----------------- HEADER ROI -----------------
st.title("⚡ Olist Supply Chain Routing Optimizer")
st.markdown("Pre-computed Medallion Marts showing impact of regional hub consolidation against direct logistics.")

if filtered_exec.empty:
    st.warning("No data found matching the selected filters.")
else:
    # ROI Metrics Calculations
    total_baseline_freight = filtered_exec["actual_freight"].sum()
    total_opt_freight = filtered_exec["optimized_freight"].sum()
    freight_savings = total_baseline_freight - total_opt_freight
    freight_savings_pct = (freight_savings / total_baseline_freight * 100) if total_baseline_freight > 0 else 0
    
    avg_days_saved = filtered_exec["days_saved"].mean()
    
    # Calculate OTIF (On-Time in Full) lift
    # On-Time Baseline = orders not late
    baseline_on_time = len(filtered_exec[filtered_exec["actual_shipping_days"] <= 20])  # Assuming standard 20 day SLA
    opt_on_time = len(filtered_exec[filtered_exec["is_optimized_late"] == 0])
    otif_lift = ((opt_on_time - baseline_on_time) / len(filtered_exec) * 100) if len(filtered_exec) > 0 else 0

    # Executive KPI Metric layout
    kpi_col1, kpi_col2, kpi_col3 = st.columns(3)
    
    with kpi_col1:
        st.metric(
            label="Total Freight Cost Savings",
            value=f"${freight_savings:,.2f}",
            delta=f"-{freight_savings_pct:.1f}% Freight Cost"
        )
    with kpi_col2:
        st.metric(
            label="Average Transit Compression",
            value=f"{avg_days_saved:.1f} Days Saved",
            delta="Faster Delivery Time",
            delta_color="normal"
        )
    with kpi_col3:
        st.metric(
            label="OTIF Service Level Lift",
            value=f"+{otif_lift:.1f}%",
            delta="Reduced Late Deliveries"
        )

    st.markdown("---")

    # ----------------- MAP & VISUALS LAYOUT -----------------
    map_col, chart_col = st.columns([1.6, 1])
    
    with map_col:
        st.subheader("3D Regional Logistics Routing Network")
        
        # Configure Pydeck Map Layers
        layers = []

        # 0. Vibrant state borders for clear geographic distinction (Neon Lavender)
        state_borders_layer = pdk.Layer(
            "GeoJsonLayer",
            "https://raw.githubusercontent.com/luizpedone/municipal-brazil-geojson/master/brazil_states.geojson",
            stroked=True,
            filled=False,
            get_line_color="[224, 176, 255, 220]",  # Neon Lavender (high opacity)
            get_line_width=8000,                    # Extra bold borders in meters
            line_width_min_pixels=2.0,              # Keep thick when zoomed out
            pickable=False
        )

        layers.append(state_borders_layer)

        
        # 1. Red Arcs representing long-haul direct baseline routes
        if scenario_mode in ["Baseline Routes", "Side-by-Side Comparison"]:
            red_arc_layer = pdk.Layer(
                "ArcLayer",
                data=filtered_spatial,
                get_source_position="[seller_lon, seller_lat]",
                get_target_position="[customer_lon, customer_lat]",
                get_source_color="[220, 53, 69, 70]",
                get_target_color="[220, 53, 69, 100]",
                width_min_pixels=1.2,
                pickable=False,
                auto_highlight=False,
            )
            layers.append(red_arc_layer)
            
        # 2. Green Arcs representing optimized short-haul routes from regional hubs
        if scenario_mode in ["Optimized Hubs", "Side-by-Side Comparison"]:
            green_arc_layer = pdk.Layer(
                "ArcLayer",
                data=filtered_spatial,
                get_source_position="[hub_lon, hub_lat]",
                get_target_position="[customer_lon, customer_lat]",
                get_source_color="[40, 167, 69, 120]",
                get_target_color="[40, 167, 69, 150]",
                width_min_pixels=1.2,
                pickable=False,
                auto_highlight=False,
            )
            layers.append(green_arc_layer)

        # Count orders routed to each hub dynamically from filtered_exec
        sp_orders = len(filtered_exec[~filtered_exec["customer_state"].isin(["RJ", "MG"])]) if not filtered_exec.empty else 0
        rj_orders = len(filtered_exec[filtered_exec["customer_state"] == "RJ"]) if not filtered_exec.empty else 0
        mg_orders = len(filtered_exec[filtered_exec["customer_state"] == "MG"]) if not filtered_exec.empty else 0

        # 3. Yellow/Gold Extruded Hub Columns representing Hub inventory locations
        # We pre-format orders and capacity to strings in Python to bypass Pydeck/JS template formatting issues
        hub_data = pd.DataFrame([
            {
                "hub_name": "Sao Paulo Hub", 
                "lat": -23.5505, 
                "lon": -46.6333, 
                "capacity": "150,000", 
                "orders_handled": sp_orders,
                "order_count": f"{sp_orders:,}"
            },
            {
                "hub_name": "Rio de Janeiro Hub", 
                "lat": -22.9068, 
                "lon": -43.1729, 
                "capacity": "90,000", 
                "orders_handled": rj_orders,
                "order_count": f"{rj_orders:,}"
            },
            {
                "hub_name": "Belo Horizonte Hub", 
                "lat": -19.9167, 
                "lon": -43.9345, 
                "capacity": "60,000", 
                "orders_handled": mg_orders,
                "order_count": f"{mg_orders:,}"
            }
        ])
        
        if scenario_mode in ["Optimized Hubs", "Side-by-Side Comparison"]:
            gold_hub_layer = pdk.Layer(
                "ColumnLayer",
                data=hub_data,
                get_position="[lon, lat]",
                get_elevation="orders_handled",
                elevation_scale=0.5,
                radius=4000,
                get_fill_color="[255, 193, 7, 210]",
                pickable=True,
                auto_highlight=True
            )
            layers.append(gold_hub_layer)

        # Calculate dynamic map center based on selected routes to prevent manual panning
        if not filtered_spatial.empty:
            center_lat = float(filtered_spatial["customer_lat"].mean())
            center_lon = float(filtered_spatial["customer_lon"].mean())
            zoom_level = 5 if len(selected_states) > 3 else 6
        else:
            center_lat = -22.5
            center_lon = -45.0
            zoom_level = 5

        # Render Map with Pydeck (Tooltips enabled ONLY for interactive hub column queries)
        st.pydeck_chart(
            pdk.Deck(
                map_style="mapbox://styles/mapbox/dark-v9",
                initial_view_state=pdk.ViewState(
                    latitude=center_lat,
                    longitude=center_lon,
                    zoom=zoom_level,
                    pitch=40,
                    bearing=0
                ),
                layers=layers,

                tooltip={
                    "html": "<b>{hub_name}</b><br/>Orders Handled: {order_count}<br/>Capacity Allocation: {capacity}",
                    "style": {
                        "backgroundColor": "#1a1e24",
                        "color": "white",
                        "fontSize": "13px",
                        "fontFamily": "Inter, sans-serif",
                        "border": "1px solid #2d3139",
                        "borderRadius": "5px",
                        "padding": "10px",
                        "zIndex": 1000
                    }
                }
            )
        )


        
    with chart_col:
        st.subheader("Transit Lead Time Compression")
        
        # Dual overlay Plotly histogram
        fig = go.Figure()
        
        fig.add_trace(go.Histogram(
            x=filtered_exec["actual_shipping_days"],
            name="Baseline Transit Time",
            xbins=dict(start=0, end=40, size=1.5),
            marker_color="#ef5350",
            opacity=0.6
        ))
        
        fig.add_trace(go.Histogram(
            x=filtered_exec["optimized_shipping_days"],
            name="Optimized Hub Transit Time",
            xbins=dict(start=0, end=40, size=1.5),
            marker_color="#26a69a",
            opacity=0.65
        ))
        
        fig.update_layout(
            barmode="overlay",
            paper_bgcolor="rgba(0,0,0,0)",
            plot_bgcolor="rgba(0,0,0,0)",
            font=dict(color="#8f9aa9"),
            legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
            margin=dict(l=0, r=0, t=30, b=0),
            xaxis_title="Shipping Days",
            yaxis_title="Order Volume Count"
        )
        
        fig.update_xaxes(showgrid=True, gridcolor="#262b32")
        fig.update_yaxes(showgrid=True, gridcolor="#262b32")
        
        st.plotly_chart(fig, use_container_width=True, config={'displayModeBar': False})

        st.subheader("📍 Top Corridor Efficiency Scorecard")
        
        # Merge datasets to link seller origin state with executive metrics
        if not filtered_exec.empty and not filtered_spatial.empty:
            merged_df = pd.merge(
                filtered_exec,
                filtered_spatial[["order_key", "seller_state", "seller_city", "customer_city"]],
                on="order_key",
                how="inner"
            )
            
            if not merged_df.empty:
                # Cast metrics to numeric types to avoid decimal.Decimal numpy round errors
                merged_df["days_saved"] = pd.to_numeric(merged_df["days_saved"], errors="coerce")
                merged_df["freight_dollars_saved"] = pd.to_numeric(merged_df["freight_dollars_saved"], errors="coerce")
                merged_df["actual_freight"] = pd.to_numeric(merged_df["actual_freight"], errors="coerce")

                # Group by Origin and Destination corridor
                corridor_df = merged_df.groupby(["seller_state", "customer_state"]).agg(
                    total_orders=("order_key", "nunique"),
                    avg_days_saved=("days_saved", "mean"),
                    total_freight_saved=("freight_dollars_saved", "sum"),
                    total_actual_freight=("actual_freight", "sum")
                ).reset_index()
                
                # Convert corridor aggregated columns to float to ensure rounding succeeds
                corridor_df["total_freight_saved"] = pd.to_numeric(corridor_df["total_freight_saved"], errors="coerce")
                corridor_df["total_actual_freight"] = pd.to_numeric(corridor_df["total_actual_freight"], errors="coerce")
                corridor_df["avg_days_saved"] = pd.to_numeric(corridor_df["avg_days_saved"], errors="coerce")
                
                # Calculate percentages and round values
                corridor_df["freight_pct"] = (corridor_df["total_freight_saved"] / corridor_df["total_actual_freight"] * 100).round(1)
                corridor_df["avg_days_saved"] = corridor_df["avg_days_saved"].round(1)
                corridor_df["total_freight_saved"] = corridor_df["total_freight_saved"].round(2)
                
                # Sort by highest traffic corridor
                corridor_df = corridor_df.sort_values(by="total_orders", ascending=False).head(5)
                
                # Select and rename columns for clean display
                corridor_df = corridor_df[[
                    "seller_state", "customer_state", "total_orders", 
                    "avg_days_saved", "total_freight_saved", "freight_pct"
                ]]
                corridor_df.columns = [
                    "Origin (Seller)", "Destination (Customer)", "Orders Handled", 
                    "Avg Days Saved", "Total Saved ($)", "Cost Reduced (%)"
                ]
                
                # Render beautiful Streamlit DataFrame
                st.dataframe(corridor_df, use_container_width=True, hide_index=True)
            else:
                st.info("Select more states to view corridor metrics.")
        else:
            st.info("Select customer states in the sidebar to populate the corridor scorecard.")

