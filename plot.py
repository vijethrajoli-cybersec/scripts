import pandas as pd
import matplotlib.pyplot as plt

# Load CSV logs
host_metrics = pd.read_csv("C:/Logs/host_metrics.csv", parse_dates=["Timestamp"])
file_stats = pd.read_csv("C:/Logs/file_stats.csv", parse_dates=["Timestamp"])

# Plot CPU, Memory Used, Disk I/O over time
plt.figure(figsize=(16, 10))
plt.plot(host_metrics["Timestamp"], host_metrics["CPU_Usage"], label="CPU Usage (%)")
plt.plot(host_metrics["Timestamp"], host_metrics["Mem_Used_MB"], label="Memory Used (MB)")  # Updated here
plt.plot(host_metrics["Timestamp"], host_metrics["Disk_BytesPerSec"], label="Disk Bytes/sec")
plt.xlabel("Time")
plt.ylabel("Usage")
plt.title("Host Metrics Over Time")
plt.legend()
plt.grid(True)
plt.tight_layout()
plt.savefig("C:/Logs/host_metrics_plot.png")
plt.show()

# Plot Entropy Changes
plt.figure(figsize=(16, 10))
entropy_series = file_stats.groupby("Timestamp")["Entropy"].mean()
plt.plot(entropy_series.index, entropy_series.values, label="Avg File Entropy", color="purple")
plt.xlabel("Time")
plt.ylabel("Entropy")
plt.title("Average File Entropy Over Time")
plt.grid(True)
plt.tight_layout()
plt.savefig("C:/Logs/file_entropy_plot.png")
plt.show()
