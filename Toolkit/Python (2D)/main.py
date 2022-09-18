from CDC import CDC
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import time
import math
raw_data = pd.read_table('DS2.txt', header=None)
X = np.array(raw_data)
data = X[:, :2]
ref = X[:, 2]
time_start = time.time()
res = CDC(30, 0.1, data)
time_end = time.time()
print(time_end-time_start)

plt.scatter(data[:, 0], data[:, 1], c=res, s=10, cmap='hsv', marker='o')
plt.show()


