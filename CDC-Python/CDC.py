def CDC(k_num, T_DCM, X):
    from sklearn.neighbors import NearestNeighbors
    import numpy as np
    import math
    num = len(X)
    nbrs = NearestNeighbors(n_neighbors=k_num+1, algorithm='ball_tree').fit(X)
    indices = nbrs.kneighbors(X, return_distance=False)
    get_knn = indices[:, 1:k_num+1]

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
                    angle[i, j] = 2 * math.pi+math.atan(delta_y / delta_x)
            else:
                angle[i, j] = math.pi + math.atan(delta_y / delta_x)

    angle_var = np.zeros(num)
    for i in range(num):
        angle_order = sorted(angle[i, :])

        for j in range(k_num-1):
            point_angle = angle_order[j + 1] - angle_order[j]
            angle_var[i] = angle_var[i] + pow(point_angle - 2 * math.pi / k_num, 2)

        point_angle = angle_order[0] - angle_order[k_num-1] + 2 * math.pi
        angle_var[i] = angle_var[i] + pow(point_angle - 2 * math.pi / k_num, 2)
        angle_var[i] = angle_var[i] / k_num

    angle_var = angle_var / ((k_num - 1) * 4 * pow(math.pi, 2) / pow(k_num, 2))

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