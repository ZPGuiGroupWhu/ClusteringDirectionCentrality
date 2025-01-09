from CDC import CDC
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import time
import math
raw_data = pd.read_table('DS1.txt', header=None)
X = np.array(raw_data)
[n, d] = X.shape
data = X[:, :d-1]
ref = X[:, d-1]
time_start = time.time()
res = CDC(30, 0.72, data)
time_end = time.time()
print(time_end-time_start)

plt.scatter(data[:, 0], data[:, 1], c=res, s=10, cmap='hsv', marker='o')
plt.show()


