rm(list=ls())
require(e1071)
bbalance <- read_csv("./input/bureau_balance.csv") 
bureau <- read_csv("./input/bureau.csv")
cc_balance <- read_csv("./input/credit_card_balance.csv")
payments <- read_csv("./input/installments_payments.csv") 
pc_balance <- read_csv("./input/POS_CASH_balance.csv")
prev <- read_csv("./input/previous_application.csv")
tr <- read_csv("./input/application_train.csv") 
te <- read_csv("./input/application_test.csv")

#---------------------------
cat("Preprocessing...\n")

fn <- funs(mean, mad, median, IQR, skewness, kurtosis, sd, min, max, sum, n_distinct, .args = list(na.rm = TRUE))

?skewness

sum_bbalance <- bbalance %>%
  mutate_if(is.character, funs(factor(.) %>% as.integer)) %>% 
  group_by(SK_ID_BUREAU) %>% 
  summarise_if(is.numeric, fn) 

#glimpse(sum_bbalance)

rm(bbalance); 
gc()

sum_bureau <- bureau %>% 
  left_join(sum_bbalance, by = "SK_ID_BUREAU") %>% 
  select(-SK_ID_BUREAU) %>% 
  mutate_if(is.character, funs(factor(.) %>% as.integer)) %>% 
  group_by(SK_ID_CURR) %>% 
  summarise_all(fn)

rm(bureau, sum_bbalance); gc()

sum_cc_balance <- cc_balance %>% 
  select(-SK_ID_PREV) %>% 
  mutate_if(is.character, funs(factor(.) %>% as.integer)) %>% 
  group_by(SK_ID_CURR) %>% 
  summarise_all(fn)

rm(cc_balance); gc()

sum_payments <- payments %>% 
  select(-SK_ID_PREV) %>% 
  group_by(SK_ID_CURR) %>% 
  summarise_all(fn) 

rm(payments); gc()

sum_pc_balance <- pc_balance %>% 
  select(-SK_ID_PREV) %>% 
  mutate_if(is.character, funs(factor(.) %>% as.integer)) %>% 
  group_by(SK_ID_CURR) %>% 
  summarise_all(fn)

rm(pc_balance); gc()

sum_prev <- prev %>%
  select(-SK_ID_PREV) %>% 
  mutate_if(is.character, funs(factor(.) %>% as.integer)) %>% 
  mutate(DAYS_FIRST_DRAWING = ifelse(DAYS_FIRST_DRAWING == 365243, NA, DAYS_FIRST_DRAWING),
         DAYS_FIRST_DUE = ifelse(DAYS_FIRST_DUE == 365243, NA, DAYS_FIRST_DUE),
         DAYS_LAST_DUE_1ST_VERSION = ifelse(DAYS_LAST_DUE_1ST_VERSION == 365243, NA, DAYS_LAST_DUE_1ST_VERSION),
         DAYS_LAST_DUE = ifelse(DAYS_LAST_DUE == 365243, NA, DAYS_LAST_DUE),
         DAYS_TERMINATION = ifelse(DAYS_TERMINATION == 365243, NA, DAYS_TERMINATION),
         APP_CREDIT_PERC = AMT_APPLICATION / AMT_CREDIT) %>% 
  group_by(SK_ID_CURR) %>% 
  summarise_all(fn) 

rm(prev); gc()

tri <- 1:nrow(tr)
y <- tr$TARGET

tr_te <- tr %>% 
  select(-TARGET) %>% 
  bind_rows(te) %>%
  left_join(sum_bureau, by = "SK_ID_CURR") %>% 
  left_join(sum_cc_balance, by = "SK_ID_CURR") %>% 
  left_join(sum_payments, by = "SK_ID_CURR") %>% 
  left_join(sum_pc_balance, by = "SK_ID_CURR") %>% 
  left_join(sum_prev, by = "SK_ID_CURR") %>% 
  select(-SK_ID_CURR) %>% 
  mutate_if(is.character, funs(factor(.) %>% as.integer)) %>% 
  mutate(na = apply(., 1, function(x) sum(is.na(x))),
         DAYS_EMPLOYED = ifelse(DAYS_EMPLOYED == 365243, NA, DAYS_EMPLOYED),
         DAYS_EMPLOYED_PERC = DAYS_EMPLOYED / DAYS_BIRTH,
         DAYS_EMPLOYED_PERC_NRM = sqrt(DAYS_EMPLOYED / DAYS_BIRTH),
         INCOME_CREDIT_PERC = AMT_INCOME_TOTAL / AMT_CREDIT,
         INCOME_PER_PERSON = AMT_INCOME_TOTAL / CNT_FAM_MEMBERS,
         INCOME_PER_PERSON_NRM = log1p(AMT_INCOME_TOTAL / CNT_FAM_MEMBERS),
         ANNUITY_INCOME_PERC = AMT_ANNUITY / AMT_INCOME_TOTAL,
         ANNUITY_INCOME_PERC_NRM = sqrt(AMT_ANNUITY / AMT_INCOME_TOTAL),
         LOAN_INCOME_RATIO = AMT_CREDIT / AMT_INCOME_TOTAL,
         ANNUITY_LENGTH = AMT_CREDIT / AMT_ANNUITY,
         CHILDREN_RATIO = CNT_CHILDREN / CNT_FAM_MEMBERS) %>%
  mutate_all(funs(ifelse(is.nan(.), NA, .))) %>% 
  mutate_all(funs(ifelse(is.infinite(.), NA, .)))  
  #data.matrix()

colnames(tr_te)
ls()
traindata <- tr_te[tri, ]

na.fill <- purrr::map(traindata, function(column) {
  if (is.numeric(column)) {
    return(median(column, na.rm = T))
  } else {
    column.tbl <- table(column)
    return(names(column.tbl)[which.max(column.tbl)])
  }
})

testdata <- tr_te[-tri, ]

traindata <- tidyr::replace_na(traindata, replace = na.fill) %>% data.matrix()
testdata <- tidyr::replace_na(testdata, replace = na.fill) %>% data.matrix()

glimpse(traindata)

#rm(tr, te, fn, sum_bureau, sum_cc_balance, 
#   sum_payments, sum_pc_balance, sum_prev); gc()

head(tr_te)
dim(tr_te)
glimpse(tr_te)

#---------------------------

cat("Preparing data...\n")
dtest <- xgb.DMatrix(data = testdata)
tr_te <- traindata

tri <- caret::createDataPartition(y, p = 0.9, list = F) %>% c()
dtrain <- xgb.DMatrix(data = tr_te[tri, ], label = y[tri])
dval <- xgb.DMatrix(data = tr_te[-tri, ], label = y[-tri])
cols <- colnames(traindata)


lgb.train = lgb.Dataset(tr_te[tri, ], label = y[tri])
lgb.valid = lgb.Dataset(data = tr_te[-tri, ], label = y[-tri])


params.lgb = list(
  objective = "binary"
  , metric = "auc"
  , min_data_in_leaf = 1
  , min_sum_hessian_in_leaf = 100
  , feature_fraction = 1
  , bagging_fraction = 1
  , bagging_freq = 0
)

# Get the time to train the lightGBM model

lgb.model <- lgb.train(
  params = params.lgb
  , data = lgb.train
  , valids = list(val = lgb.valid)
  , learning_rate = 0.05
  , num_leaves = 7
  , num_threads = 2
  , nrounds = 3000
  , early_stopping_rounds = 200
  , eval_freq = 50
)

lgb.importance(lgb.model, percentage = TRUE) %>% head(20) %>% kable()
tree_imp <- lgb.importance(lgb.model, percentage = TRUE) %>% head(20)
lgb.plot.importance(tree_imp, measure = "Gain")

lgb_pred <- predict(lgb.model, data = data.matrix(testdata), n = lgb.model$best_iter)

result <- data.frame(SK_ID_CURR = as.integer(SK_ID_CURR), TARGET = lgb_pred)

read_csv("./input/sample_submission.csv") %>%  
  mutate(SK_ID_CURR = as.integer(SK_ID_CURR),
         TARGET =  predict(lgb.model, data = data.matrix(testdata), n = lgb.model$best_iter)) %>%
  write_csv(paste0("0622_lgb_pred2", ".csv"))



rm(tr_te, y, tri); gc()

#---------------------------
cat("Training model...\n")
p <- list(objective = "binary:logistic",
          booster = "gbtree",
          eval_metric = "auc",
          nthread = 4,
          eta = 0.01,
          max_depth = 6,
          min_child_weight = 22,
          gamma = 0,
          subsample = 0.775,
          colsample_bytree = 0.7,
          colsample_bylevel = 0.7,
          alpha = 0,
          lambda = 0,
          nrounds = 2000)

set.seed(0)
m_xgb <- xgb.train(p, dtrain, p$nrounds, list(val = dval), print_every_n = 50, early_stopping_rounds = 250)

xgb.importance(cols, model=m_xgb) %>% 
  xgb.plot.importance(top_n = 30)

#---------------------------
read_csv("./input/sample_submission.csv") %>%  
  mutate(SK_ID_CURR = as.integer(SK_ID_CURR),
         TARGET = predict(m_xgb, dtest)) %>%
  write_csv(paste0("tidy_xgb_3", round(m_xgb$best_score, 5), ".csv"))
