import pandas as pd
import matplotlib.pyplot as plt

# Load host metrics CSV
csv_path = "C:/Logs/host_metrics.csv"
df = pd.read_csv(csv_path, parse_dates=["Timestamp"])

# Convert columns to float (if stored as strings)
cols_to_float = ["CPU_Usage", "Mem_Usage_MB", "Disk_BytesPerSec_KB", "FileIO_BytesPerSec_KB"]
for col in cols_to_float:
    df[col] = pd.to_numeric(df[col], errors="coerce")

# Drop rows with missing data
df.dropna(subset=cols_to_float, inplace=True)

# Plot
plt.figure(figsize=(14, 7))
plt.plot(df["Timestamp"], df["CPU_Usage"], label="CPU Usage (%)")
plt.plot(df["Timestamp"], df["Mem_Usage_MB"], label="Memory Usage (MB)")
plt.plot(df["Timestamp"], df["Disk_BytesPerSec_KB"], label="Disk IOPS (KB/s)")
plt.plot(df["Timestamp"], df["FileIO_BytesPerSec_KB"], label="File IOPS (KB/s)")

plt.title("Host Metrics Over Time")
plt.xlabel("Time")
plt.ylabel("Metric Value")
plt.legend()
plt.grid(True)
plt.tight_layout()
plt.savefig("C:/Logs/host_metrics_plot.png")
plt.show()
