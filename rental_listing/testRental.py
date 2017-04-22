import os
import sys
import operator
import numpy as np
import pandas as pd
from scipy import sparse
import xgboost as xgb
import random
from sklearn import model_selection, preprocessing, ensemble
from sklearn.metrics import log_loss
from sklearn.feature_extraction.text import TfidfVectorizer, CountVectorizer


#input data
train_df=pd.read_json('./input/train.json')
test_df=pd.read_json('./input/test.json')

#
#Now add some basic feature.
#

#basic features
train_df["price_t"] =train_df["price"]/train_df["bedrooms"] #베드룸당 가격
test_df["price_t"] = test_df["price"]/test_df["bedrooms"]
train_df["room_sum"] = train_df["bedrooms"]+train_df["bathrooms"] #총 방의 개수
test_df["room_sum"] = test_df["bedrooms"]+test_df["bathrooms"]

# count of photos #
train_df["num_photos"] = train_df["photos"].apply(len) # photos key에 대한 value인 배열의 길이
test_df["num_photos"] = test_df["photos"].apply(len)

# count of "features" #
train_df["num_features"] = train_df["features"].apply(len) # features라는 key에 대한 value인 string의 길이
test_df["num_features"] = test_df["features"].apply(len)

# count of words present in description column #
train_df["num_description_words"] = train_df["description"].apply(lambda x: len(x.split(" "))) #description은 split한 개수를 반환
test_df["num_description_words"] = test_df["description"].apply(lambda x: len(x.split(" ")))


# 원래 있던 original값들과 새로만든 feature를 넣어 feature_to_use 리스트 만듬
features_to_use=["bathrooms", "bedrooms", "latitude", "longitude", "price","price_t","num_photos", "num_features", "num_description_words","listing_id"]

#
#Define XGB function, it come from "XGB starter in python" by SRK
#

def runXGB(train_X, train_y, test_X, test_y=None, feature_names=None, seed_val=0, num_rounds=1000):
    param = {}
    param['objective'] = 'multi:softprob'
    param['eta'] = 0.03 # 알파값?
    param['max_depth'] = 6
    param['silent'] = 1
    param['num_class'] = 3
    param['eval_metric'] = "mlogloss"
    param['min_child_weight'] = 1
    param['subsample'] = 0.7 # 70프로만 뽑겠다
    param['colsample_bytree'] = 0.7 # 컬럼의 ratio 최대 몇개만 쓰겠다라는 의미?
    param['seed'] = seed_val # 초기값 설정 랜덤 안되게
    num_rounds = num_rounds

    plst = list(param.items())
    xgtrain = xgb.DMatrix(train_X, label=train_y) # D매트릭스로 바꿔줘야 한다.

    # test의 타겟값을 넣은 xgb model
    if test_y is not None:
        xgtest = xgb.DMatrix(test_X, label=test_y)
        watchlist = [ (xgtrain,'train'), (xgtest, 'test') ]
        model = xgb.train(plst, xgtrain, num_rounds, watchlist, early_stopping_rounds=20)
    # test의 타겟값을 넣지 않은 xgb model
    else:
        xgtest = xgb.DMatrix(test_X)
        model = xgb.train(plst, xgtrain, num_rounds)

    pred_test_y = model.predict(xgtest)
    return pred_test_y, model

#
#CV statistics, only change here
#

index=list(range(train_df.shape[0])) # train data 의 수만큼의 list를 만듬
random.shuffle(index) # 값 셔플
a=[np.nan]*len(train_df) # 데이터 수만큼 리스트 만들고
b=[np.nan]*len(train_df)
c=[np.nan]*len(train_df)

for i in range(5): # 데이터를 5등분할 계획
    building_level={}
    for j in train_df['manager_id'].values: # 매니저id를 key로 하는 building_level을 만들고
        building_level[j]=[0,0,0]
    test_index=index[int((i*train_df.shape[0])/5):int(((i+1)*train_df.shape[0])/5)] # 데이터를 5등분함
    train_index=list(set(index).difference(test_index)) # 나머지 4/5의 양에 해당하는 데이터를 train 데이터로 함. cross validation? 그거를 위한 것인듯
    for j in train_index: # train데이터를 돌면서 '매니저 당 각interest level에 대한 count 정보'를 저장함
        temp=train_df.iloc[j] # j-1번지 주소 데이터 값 
        if temp['interest_level']=='low':
            building_level[temp['manager_id']][0]+=1
        if temp['interest_level']=='medium':
            building_level[temp['manager_id']][1]+=1
        if temp['interest_level']=='high':
            building_level[temp['manager_id']][2]+=1
    for j in test_index: # train 데이터를 바탕으로 test데이터에 manager에 대한 interest level별 비율정보를 넣어준다
        temp=train_df.iloc[j]
        if sum(building_level[temp['manager_id']])!=0:
            a[j]=building_level[temp['manager_id']][0]*1.0/sum(building_level[temp['manager_id']])
            b[j]=building_level[temp['manager_id']][1]*1.0/sum(building_level[temp['manager_id']])
            c[j]=building_level[temp['manager_id']][2]*1.0/sum(building_level[temp['manager_id']])
# 5번 돌면 모든 데이터 값 채워짐

train_df['manager_level_low']=a
train_df['manager_level_medium']=b
train_df['manager_level_high']=c



# 이번엔 한번에! train데이터로부터 매니저에 대한 interest level별 count정보를 집계
a=[]
b=[]
c=[]
building_level={}
for j in train_df['manager_id'].values:
    building_level[j]=[0,0,0]
for j in range(train_df.shape[0]): 
    temp=train_df.iloc[j] # 각 매물의 interset level을 확인하여 매니저id별로 정리해나감
    if temp['interest_level']=='low':
        building_l감vel[temp['manager_id']][0]+=1
    if temp['interest_level']=='medium':
        building_level[temp['manager_id']][1]+=1
    if temp['interest_level']=='high':
        building_level[temp['manager_id']][2]+=1

for i in test_df['manager_id'].values:
    if i not in building_level.keys():
        a.append(np.nan)
        b.append(np.nan)
        c.append(np.nan)
    else:
        a.append(building_level[i][0]*1.0/sum(building_level[i]))
        b.append(building_level[i][1]*1.0/sum(building_level[i]))
        c.append(building_level[i][2]*1.0/sum(building_level[i]))
test_df['manager_level_low']=a
test_df['manager_level_medium']=b
test_df['manager_level_high']=c
# 이번엔 train데이터를 통해 집계한 매니저에 대한 'interest level별 count정보'로 test데이터의 'manager에 대한 interest level별 비율정보'을 구함

#위에서 애써만든 매니저 평가정보를 여기에서 feature에 포함시킴
features_to_use.append('manager_level_low')
features_to_use.append('manager_level_medium')
features_to_use.append('manager_level_high')



# 범주형 데이터를 넣는 과정
categorical = ["display_address", "manager_id", "building_id", "street_address"]
for f in categorical:
        if train_df[f].dtype=='object':
            #print(f)
            lbl = preprocessing.LabelEncoder() #범주형 변수를 사용하기 위해 팩터화시키는것
            lbl.fit(list(train_df[f].values) + list(test_df[f].values))
            train_df[f] = lbl.transform(list(train_df[f].values))
            test_df[f] = lbl.transform(list(test_df[f].values))
            features_to_use.append(f)



# original데이터의 features컬럼을 tfidf 팩터화
train_df['features'] = train_df["features"].apply(lambda x: " ".join(["_".join(i.split(" ")) for i in x]))
test_df['features'] = test_df["features"].apply(lambda x: " ".join(["_".join(i.split(" ")) for i in x]))
print(train_df["features"].head())
tfidf = CountVectorizer(stop_words='english', max_features=200) # english를 위한 처리 
tr_sparse = tfidf.fit_transform(train_df["features"]) # 200차원으로 잘라놓으면 sparse형태로 바꿔준다.
te_sparse = tfidf.transform(test_df["features"])



# 10
# 10000     Doorman Elevator Fitness_Center Cats_Allowed D...
# 100004    Laundry_In_Building Dishwasher Hardwood_Floors...
# 100007                               Hardwood_Floors No_Fee
# 100013                                              Pre-War
# Name: features, dtype: object


# xgb에 넣기위해 자료구조를 만듬
train_X = sparse.hstack([train_df[features_to_use], tr_sparse]).tocsr()
test_X = sparse.hstack([test_df[features_to_use], te_sparse]).tocsr()

target_num_map = {'high':0, 'medium':1, 'low':2}
train_y = np.array(train_df['interest_level'].apply(lambda x: target_num_map[x]))
print(train_X.shape, test_X.shape)

# (49352, 217) (74659, 217)
# Without CV statistic,to score get 0.5480 by SRK. And CV statistic get 0.5346 In fact ,you need to turn down the learning rate and turn up run_num

# 교차검증 방법 사용
# 하지만 iteration을 한번만 돌고 있다. train데이터와 val데이터로 나눠서 test데이터에 대한 label값을 넣은 방식으로 xgb했다는 의미가 더 크다. + 내부 검증
cv_scores = []
kf = model_selection.KFold(n_splits=5, shuffle=True, random_state=2016)
for dev_index, val_index in kf.split(range(train_X.shape[0])):
        dev_X, val_X = train_X[dev_index,:], train_X[val_index,:]
        dev_y, val_y = train_y[dev_index], train_y[val_index]
        preds, model = runXGB(dev_X, dev_y, val_X, val_y)
        cv_scores.append(log_loss(val_y, preds))
        print(cv_scores)
        break


# Stopping. Best iteration:
# [947]	train-mlogloss:0.354195	test-mlogloss:0.534228
#
# [0.5342823158148593]

# 본격 test를 예측한다.
preds, model = runXGB(train_X, train_y, test_X, num_rounds=1000)
out_df = pd.DataFrame(preds)
out_df.columns = ["high", "medium", "low"]
out_df["listing_id"] = test_df.listing_id.values
out_df.to_csv("xgb_starter2.csv", index=False)

# 0.53601