import pandas as pd
import matplotlib.pyplot as plt

# Load the host metrics CSV
df = pd.read_csv("C:/Logs/host_metrics.csv", parse_dates=["Timestamp"])

# Convert Timestamp column if needed
if df["Timestamp"].dtype == 'O':
    df["Timestamp"] = pd.to_datetime(df["Timestamp"])

# Set up the figure
plt.figure(figsize=(20, 10))

# Plot metrics
plt.plot(df["Timestamp"], df["CPU_Usage"], label="CPU Usage (%)", color='blue')
plt.plot(df["Timestamp"], df["Mem_Used_MB"], label="Memory Used (MB)", color='orange')
plt.plot(df["Timestamp"], df["Disk_BytesPerSec"], label="Disk IOPS (Bytes/sec)", color='green')
plt.plot(df["Timestamp"], df["FileIO_BytesPerSec"], label="File IOPS (Bytes/sec)", color='red')

# Format plot
plt.xlabel("Time")
plt.ylabel("Metric Value")
plt.title("Host Metrics Over Time")
plt.legend()
plt.grid(True)
plt.tight_layout()

# Save and display
plt.savefig("C:/Logs/host_metrics_plot.png")
plt.show()
