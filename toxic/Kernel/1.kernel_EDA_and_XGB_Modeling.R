##################################################
# Toxic Comment Classification Challenge
# Kernel : Toxic Comments EDA and XGB Modelling
# Url    : https://www.kaggle.com/ambarish/toxic-comments-eda-and-xgb-modelling
##################################################

## 1 Introduction

library(tidyverse)
#install.packages("tidytext")
library(tidytext) 
library(DT)
library(stringr)


library('wordcloud')
library(igraph)
#install.packages("ggraph")
library(ggraph)

library(tm)
library(SnowballC)

library(caret)

rm(list=ls())

fillColor = "#FFA07A"
fillColor2 = "#F1C40F"

train = read_csv("./InputData/train.csv")
test = read_csv("./InputData/test.csv")
submission =read_csv("./InputData/sample_submission.csv")

train$comment_text=gsub("'|\"|'|“|”|\"|\n|,|\\.|…|\\?|\\+|\\-|\\/|\\=|\\(|\\)|‘", "", 
                        train$comment_text)
### Section : Data Visualization
## 2. Peek into the Data
datatable(head(train), style="bootstrap", class="table-condensed", options = list(dom = 'tp',scrollX = TRUE))

## 3 Sentence Length Distribution
train$len = str_count(train$comment_text)
test$len = str_count(test$comment_text)

train %>%
  ggplot(aes(x = len)) +    
  geom_histogram(fill= fillColor2,bins = 50) +
  labs(x= 'Word Length',y = 'Count', title = paste("Distribution of", ' Word Length ')) +
  theme_bw()

## 4 Top Ten most Common Words
createBarPlotCommonWords = function(train,title)
{
  train %>%
    unnest_tokens(word, comment_text) %>%
    filter(!word %in% stop_words$word) %>%
    count(word,sort = TRUE) %>%
    ungroup() %>%
    mutate(word = factor(word, levels = rev(unique(word)))) %>%
    head(10) %>%
    
    ggplot(aes(x = word,y = n)) +
    geom_bar(stat='identity',colour="white", fill =fillColor) +
    geom_text(aes(x = word, y = 1, label = paste0("(",n,")",sep="")),
              hjust=0, vjust=.5, size = 4, colour = 'black',
              fontface = 'bold') +
    labs(x = 'Word', y = 'Word Count', 
         title = title) +
    coord_flip() + 
    theme_bw()
  
}

createBarPlotCommonWords(train,'Top 10 most Common Words')

## 5 Tokenisation of the sentences
trainWords <- train %>%
  unnest_tokens(word, comment_text) %>%
  count(toxic,severe_toxic,obscene,threat,insult,identity_hate,word) %>%
  ungroup()

datatable(head(trainWords,20), style="bootstrap", class="table-condensed", options = list(dom = 'tp',scrollX = TRUE))

## 6 Unique Categories of Text
trainWords <- train %>%
  unnest_tokens(word, comment_text) %>%
  dplyr::count(toxic,severe_toxic,obscene,threat,insult,identity_hate,word) %>%
  ungroup()

total_words <- trainWords %>% 
  group_by(toxic,severe_toxic,obscene,threat,insult,identity_hate) %>% 
  summarize(total = sum(n))

total_words

## 7 TF-IDF

# 7.1 The Math
#TF(t) = (Number of times term t appears in a document) / (Total number of terms in the document)
#IDF(t) = log_e(Total number of documents / Number of documents with term t in it).
#Value = TF * IDF

# 7.2 Twenty Most Important words

Category =1:41
total_words$Category = Category


trainWords <- left_join(trainWords, total_words)

#Now we are ready to use the bind_tf_idf which computes the tf-idf for each term. 
trainWords <- trainWords %>%
  bind_tf_idf(word, Category, n)


plot_trainWords <- trainWords %>%
  arrange(desc(tf_idf)) %>%
  mutate(word = factor(word, levels = rev(unique(word))))

plot_trainWords %>% 
  top_n(20) %>%
  ggplot(aes(word, tf_idf)) +
  geom_col(fill = fillColor) +
  labs(x = NULL, y = "tf-idf") +
  coord_flip() +
  theme_bw()

## 8 Various Categories of TF-IDF
# 8.1 Toxic TF-IDF
plot_trainWords %>%
  filter(toxic == 1 ) %>%
  top_n(20) %>%
  ggplot(aes(word, tf_idf)) +
  geom_col(fill = fillColor2) +
  labs(x = NULL, y = "tf-idf") +
  coord_flip() +
  theme_bw()
# 8.2 Severe Toxic TF-IDF
plot_trainWords %>%
  filter(severe_toxic == 1 ) %>%
  top_n(20) %>%
  ggplot(aes(word, tf_idf)) +
  geom_col(fill = fillColor2) +
  labs(x = NULL, y = "tf-idf") +
  coord_flip() +
  theme_bw()
# 8.3 Obscene TF-IDF
plot_trainWords %>%
  filter(obscene == 1 ) %>%
  top_n(20) %>%
  ggplot(aes(word, tf_idf)) +
  geom_col(fill = fillColor2) +
  labs(x = NULL, y = "tf-idf") +
  coord_flip() +
  theme_bw()
# 8.4 Threat TF-IDF
plot_trainWords %>%
  filter(threat == 1 ) %>%
  top_n(20) %>%
  ggplot(aes(word, tf_idf)) +
  geom_col(fill = fillColor2) +
  labs(x = NULL, y = "tf-idf") +
  coord_flip() +
  theme_bw()

# 8.5 Insult TF-IDF
plot_trainWords %>%
  filter(insult == 1 ) %>%
  top_n(20) %>%
  ggplot(aes(word, tf_idf)) +
  geom_col(fill = fillColor2) +
  labs(x = NULL, y = "tf-idf") +
  coord_flip() +
  theme_bw()
# 8.6 identity_hate TF-IDF
plot_trainWords %>%
  filter(identity_hate == 1 ) %>%
  top_n(20) %>%
  ggplot(aes(word, tf_idf)) +
  geom_col(fill = fillColor2) +
  labs(x = NULL, y = "tf-idf") +
  coord_flip() +
  theme_bw()

## 9 Word Cloud for the Most Important Words
plot_trainWords %>%
  with(wordcloud(word, tf_idf, max.words = 50,colors=brewer.pal(8, "Dark2")))

## 10 Document Term Matrix
#We create the DTM for both Test and Train dataset

train$comment_text = iconv(train$comment_text, 'UTF-8', 'ASCII')
train$comment_text=str_replace_all(train$comment_text,"[^[:graph:]]", " ") 

corpus = VCorpus(VectorSource(train$comment_text))
corpus = tm_map(corpus, content_transformer(tolower))
corpus = tm_map(corpus, removeNumbers)
corpus = tm_map(corpus, removePunctuation)
corpus = tm_map(corpus, removeWords, stopwords())
corpus = tm_map(corpus, stemDocument)
corpus = tm_map(corpus, stripWhitespace)


dtm = DocumentTermMatrix(corpus)
dtm = removeSparseTerms(dtm, 0.99)
dataset = as.data.frame(as.matrix(dtm))
dataset$toxic = NULL
dataset$severe_toxic = NULL
dataset$obscene = NULL
dataset$threat = NULL
dataset$insult = NULL
dataset$identity_hate = NULL

###################################################################################

test$comment_text = iconv(test$comment_text, 'UTF-8', 'ASCII')
test$comment_text=str_replace_all(test$comment_text,"[^[:graph:]]", " ") 

corpus = VCorpus(VectorSource(test$comment_text))
corpus = tm_map(corpus, content_transformer(tolower))
corpus = tm_map(corpus, removeNumbers)
corpus = tm_map(corpus, removePunctuation)
corpus = tm_map(corpus, removeWords, stopwords())
corpus = tm_map(corpus, stemDocument)
corpus = tm_map(corpus, stripWhitespace)


dtm = DocumentTermMatrix(corpus)
dtm = removeSparseTerms(dtm, 0.99)
datasetTest = as.data.frame(as.matrix(dtm))

######################################################################################

colnamesSame = intersect(colnames(dataset),colnames(datasetTest))

dataset = dataset[ , (colnames(dataset) %in% colnamesSame)]
datasetTest = datasetTest[ , (colnames(datasetTest) %in% colnamesSame)]


######################################################################################

## 11 Modelling using XGBoost
# 11.1 Toxic Calculation
#We calculate the various targets and predict the probablities

dataset2 = dataset
dataset2$toxic = train$toxic
dataset2$toxic = as.factor(dataset2$toxic)
levels(dataset2$toxic) = make.names(unique(dataset2$toxic))

formula = toxic ~ .

fitControl <- trainControl(method="none",classProbs=TRUE, summaryFunction=twoClassSummary)

xgbGrid <- expand.grid(nrounds = 500,
                       max_depth = 3,
                       eta = .05,
                       gamma = 0,
                       colsample_bytree = .8,
                       min_child_weight = 1,
                       subsample = 1)


set.seed(13)

ToxicXGB = train(formula, data = dataset2,
                 method = "xgbTree",trControl = fitControl,
                 tuneGrid = xgbGrid,na.action = na.pass,metric="ROC", maximize=FALSE)

predictionsToxic = predict(ToxicXGB,datasetTest,type = 'prob')

# 11.2 Severe Toxic Calculation
dataset2 = dataset
dataset2$severe_toxic = train$severe_toxic
dataset2$severe_toxic = as.factor(dataset2$severe_toxic)
levels(dataset2$severe_toxic) = make.names(unique(dataset2$severe_toxic))

formula = severe_toxic ~ .

set.seed(13)

ToxicXGB = train(formula, data = dataset2,
                 method = "xgbTree",trControl = fitControl,
                 tuneGrid = xgbGrid,na.action = na.pass,metric="ROC", maximize=FALSE)

predictionsSevereToxic = predict(ToxicXGB,datasetTest,type = 'prob')


# 11.3 Obscene Calculation
dataset2 = dataset
dataset2$obscene = train$obscene
dataset2$obscene = as.factor(dataset2$obscene)
levels(dataset2$obscene) = make.names(unique(dataset2$obscene))

formula = obscene ~ .

ObsceneXGB = train(formula, data = dataset2,
                   method = "xgbTree",trControl = fitControl,
                   tuneGrid = xgbGrid,na.action = na.pass,metric="ROC", maximize=FALSE)

predictionsObscene = predict(ObsceneXGB,datasetTest,type = 'prob')

# 11.4 Threat Calculation
dataset2 = dataset
dataset2$threat = train$threat
dataset2$threat = as.factor(dataset2$threat)
levels(dataset2$threat) = make.names(unique(dataset2$threat))

formula = threat ~ .

ThreatXGB = train(formula, data = dataset2,
                  method = "xgbTree",trControl = fitControl,
                  tuneGrid = xgbGrid,na.action = na.pass,metric="ROC", maximize=FALSE)

predictionsThreat = predict(ThreatXGB,datasetTest,type = 'prob')
# 11.5 Insult Calculation
dataset2 = dataset
dataset2$insult = train$insult
dataset2$insult = as.factor(dataset2$insult)
levels(dataset2$insult) = make.names(unique(dataset2$insult))

formula = insult ~ .

InsultXGB = train(formula, data = dataset2,
                  method = "xgbTree",trControl = fitControl,
                  tuneGrid = xgbGrid,na.action = na.pass,metric="ROC", maximize=FALSE)

predictionsInsult = predict(InsultXGB,datasetTest,type = 'prob')
# 11.6 Identity Hate Calculation
dataset2 = dataset
dataset2$identity_hate = train$identity_hate
dataset2$identity_hate = as.factor(dataset2$identity_hate)
levels(dataset2$identity_hate) = make.names(unique(dataset2$identity_hate))

formula = identity_hate ~ .

HateXGB = train(formula, data = dataset2,
                method = "xgbTree",trControl = fitControl,
                tuneGrid = xgbGrid,na.action = na.pass,metric="ROC", maximize=FALSE)

predictionsHate = predict(HateXGB,datasetTest,type = 'prob')
## 12 Creating the Submissions
submission$toxic = predictionsToxic$X1
submission$severe_toxic = predictionsSevereToxic$X1
submission$obscene = predictionsObscene$X1
submission$threat = predictionsThreat$X1
submission$insult = predictionsInsult$X1
submission$identity_hate = predictionsHate$X1

# Write it to file
write.csv(submission, 'ToxicCommentsJan312018.csv', row.names = F)

