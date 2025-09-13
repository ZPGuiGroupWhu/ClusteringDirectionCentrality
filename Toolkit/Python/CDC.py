import math
import numpy as np
from sklearn.neighbors import NearestNeighbors
from scipy.special import gamma
from scipy.spatial import ConvexHull

def cdc_cluster(X: np.ndarray, k_num: int, ratio: float) -> np.ndarray:
    """Clustering by measuring local Direction Centrality (CDC) algorithm.

    This function implements the CDC clustering algorithm, which is a connectivity-based
    clustering method that identifies boundary points using a directional centrality
    metric (DCM) and connects internal points to generate cluster labels. DCM is defined
    as angle variance in 2D space and simplex volume variance in higher dimensions.

    The algorithm works in several steps:
    1. For each point, find k-nearest neighbors
    2. For each point, calculate its DCM
    3. Identify boundary and internal points based on the DCM threshold
    4. Calculate reachable distances of the internal points
    5. Form clusters by connecting nearby internal points
    6. Assign boundary points to nearest clusters

    Args:
        X (np.ndarray): Input data matrix of shape (n_samples, n_features).
            Each row represents a data point and each column represents a feature.
        k_num (int): Number of nearest neighbors to consider. Must be greater than 0.
            This parameter controls the local neighborhood size.
        ratio (float): Ratio for determining the DCM threshold. Must be between 0 and 1.
            Lower values result in fewer internal points and more boundary points.


    Returns:
        np.ndarray: Cluster labels for each data point. Shape (n_samples,).
            Labels are integers starting from 1, where points with the same label
            belong to the same cluster.

    Raises:
        AssertionError: If k_num <= 0 or ratio is not in (0, 1).
        ValueError: If X is not a 2D array or has insufficient data points.

    Note:
        - For 2D data, the algorithm uses angle variance between k-nearest neighbors
        - For higher dimensional data, it uses convex hull simplex volume variance
        - The algorithm automatically handles edge cases and numerical instabilities
    """
    assert k_num > 0, "k_num must be greater than 0"
    assert 0 < ratio < 1, "ratio must be between 0 and 1"

    [num, d] = X.shape
    nbrs = NearestNeighbors(n_neighbors=k_num + 1, algorithm='ball_tree').fit(X)
    indices = nbrs.kneighbors(X, return_distance=False)
    get_knn = indices[:, 1:k_num + 1]

    angle_var = np.zeros(num)
    if (d == 2):
        angle = np.zeros((num, k_num))
        for i in range(num):
            for j in range(k_num):
                delta_x = X[get_knn[i, j], 0] - X[i, 0]
                delta_y = X[get_knn[i, j], 1] - X[i, 1]
                if delta_x == 0:
                    if delta_y == 0:
                        angle[i, j] = 0
                    elif delta_y > 0:
                        angle[i, j] = math.pi / 2
                    else:
                        angle[i, j] = 3 * math.pi / 2
                elif delta_x > 0:
                    if math.atan(delta_y / delta_x) >= 0:
                        angle[i, j] = math.atan(delta_y / delta_x)
                    else:
                        angle[i, j] = 2 * math.pi + math.atan(delta_y / delta_x)
                else:
                    angle[i, j] = math.pi + math.atan(delta_y / delta_x)

        for i in range(num):
            angle_order = sorted(angle[i, :])

            for j in range(k_num - 1):
                point_angle = angle_order[j + 1] - angle_order[j]
                angle_var[i] = angle_var[i] + pow(point_angle - 2 * math.pi / k_num, 2)

            point_angle = angle_order[0] - angle_order[k_num - 1] + 2 * math.pi
            angle_var[i] = angle_var[i] + pow(point_angle - 2 * math.pi / k_num, 2)
            angle_var[i] = angle_var[i] / k_num

        angle_var = angle_var / ((k_num - 1) * 4 * pow(math.pi, 2) / pow(k_num, 2))
    else:
        for i in range(num):
            try:
                dif_x = X[get_knn[i], :] - X[i, :]
                map_x = np.linalg.inv(np.diag(np.sqrt(np.diag(np.dot(dif_x, dif_x.T))))) @ dif_x
                hull = ConvexHull(map_x)
                simplex_num = len(hull.simplices)
                simplex_vol = np.zeros(simplex_num)

                for j in range(simplex_num):
                    simplex_coord = map_x[hull.simplices[j], :]
                    simplex_vol[j] = np.sqrt(max(0, np.linalg.det(np.dot(simplex_coord, simplex_coord.T)))) / gamma(
                        d - 1)

                angle_var[i] = np.var(simplex_vol)

            except Exception as e:
                angle_var[i] = 1

    sort_dcm = sorted(angle_var)
    T_DCM = sort_dcm[math.ceil(num * ratio)]
    ind = np.zeros(num)
    for i in range(num):
        if angle_var[i] < T_DCM:
            ind[i] = 1

    near_dis = np.zeros(num)
    for i in range(num):
        knn_ind = ind[get_knn[i, :]]
        if ind[i] == 1:
            if 0 in knn_ind:
                bdpts_ind = np.where(knn_ind == 0)
                bd_id = get_knn[i, bdpts_ind[0][0]]
                near_dis[i] = math.sqrt(sum(pow((X[i, :] - X[bd_id, :]), 2)))
            else:
                near_dis[i] = float("inf")
                for j in range(num):
                    if ind[j] == 0:
                        temp_dis = math.sqrt(sum(pow((X[i, :] - X[j, :]), 2)))
                        if temp_dis < near_dis[i]:
                            near_dis[i] = temp_dis
        else:
            if 1 in knn_ind:
                bdpts_ind = np.where(knn_ind == 1)
                bd_id = get_knn[i, bdpts_ind[0][0]]
                near_dis[i] = bd_id
            else:
                mark_dis = float("inf")
                for j in range(num):
                    if ind[j] == 1:
                        temp_dis = math.sqrt(sum(pow((X[i, :] - X[j, :]), 2)))
                        if temp_dis < mark_dis:
                            mark_dis = temp_dis
                            near_dis[i] = j

    cluster = np.zeros(num)
    mark = 1
    for i in range(num):
        if ind[i] == 1 and cluster[i] == 0:
            cluster[i] = mark
            for j in range(num):
                if ind[j] == 1 and math.sqrt(sum(pow((X[i, :] - X[j, :]), 2))) <= near_dis[i] + near_dis[j]:
                    if cluster[j] == 0:
                        cluster[j] = cluster[i]
                    else:
                        temp_cluster = cluster[j]
                        temp_ind = np.where(cluster == temp_cluster)
                        cluster[temp_ind] = cluster[i]

            mark = mark + 1

    for i in range(num):
        if ind[i] == 0:
            cluster[i] = cluster[int(near_dis[i])]

    mark = 1
    storage = np.zeros(num)
    for i in range(num):
        if cluster[i] in storage:
            temp_ind = np.where(storage == cluster[i])
            cluster[i] = cluster[temp_ind[0][0]]
        else:
            storage[i] = cluster[i]
            cluster[i] = mark
            mark = mark + 1

    return cluster