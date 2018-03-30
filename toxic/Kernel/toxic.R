##################################################
#### SETTING
##################################################

library(stringr)
library(dplyr)
library(ggplot2)
library(tidytext) 
library('wordcloud')
library(xgboost)
library(tm)
library(doParallel)

#load data
train_data <- fread("./InputData/train.csv", header = T, encoding = 'UTF-8')
test_data <- fread("./InputData/test.csv", header = T, encoding = 'UTF-8')
submission <- fread("./InputData/sample_submission.csv")

##################################################
#### DATA CLEANSING
##################################################

# define function for cleaning
cleaning_texts <- function(text){
  ## need to do tolower and remove stopwords bevor removing punctuation!!
  # all letters to lower
  text <- tolower(text)
  
  # remove linebreaks
  text <- gsub("\n", " ", text, perl = T)
  # strip multiple whitspace to one
  text <- gsub("\\s+", " ", text, perl = T)
  
  # remove links
  text <- gsub("(f|ht)tp(s?)://\\S+", "LINK", text, perl = T)
  text <- gsub("http\\S+", "LINK", text, perl = T)
  text <- gsub("xml\\S+", "LINK", text, perl = T)
  
  # transform short forms
  text <- gsub("'ll", " will", text, perl = T)
  text <- gsub("i'm", "i am", text, perl = T)
  text <- gsub("'re", " are", text, perl = T)
  text <- gsub("'s", " is", text, perl = T)
  text <- gsub("'ve", " have", text, perl = T)
  text <- gsub("'d", " would", text, perl = T)
  text <- gsub("can't", "can not", text, perl = T)
  text <- gsub("don't", "do not", text, perl = T)
  text <- gsub("doesn't", "does not", text, perl = T)
  text <- gsub("isn't", "is not", text, perl = T)
  text <- gsub("aren't", "are not", text, perl = T)
  text <- gsub("couldn't", "could not", text, perl = T)
  text <- gsub("mustn't", "must not", text, perl = T)
  text <- gsub("didn't", "did not", text, perl = T)
  
  # remove modified text
  #gsub("(?<=\\b\\w)\\s(?=\\w\\b)", "", "f u c k  y o u  a s  u  a r e  a  b i t c h  a s s  n i g g e r", perl = T)
  #gsub("(?<=\\b\\w)\\s(?=\\w\\b)", "", "n i g g e r f a g g o t", perl = T)
  text <- gsub("(?<=\\b\\w)\\s(?=\\w\\b)", "", text, perl = T)
  
  # remove "shittext"
  text <- gsub("\\b(a|e)w+\\b", "AWWWW", text, perl = T)
  text <- gsub("\\b(y)a+\\b", "YAAAA", text, perl = T)
  text <- gsub("\\b(w)w+\\b", "WWWWW", text, perl = T)
  #text <- gsub("a?(ha)+\\b", "", text, perl = T)
  text <- gsub("\\b(b+)?((h+)((a|e|i|o|u)+)(h+)?){2,}\\b", "HAHEHI", text, perl = T)
  text <- gsub("\\b(b+)?(((a|e|i|o|u)+)(h+)((a|e|i|o|u)+)?){2,}\\b", "HAHEHI", text, perl = T)
  text <- gsub("\\b(m+)?(u+)?(b+)?(w+)?((a+)|(h+))+\\b", "HAHEHI", text, perl = T)
  text <- gsub("\\b((e+)(h+))+\\b", "HAHEHI", text, perl = T)
  text <- gsub("\\b((h+)(e+))+\\b", "HAHEHI", text, perl = T)
  text <- gsub("\\b((o+)(h+))+\\b", "HAHEHI", text, perl = T)
  text <- gsub("\\b((h+)(o+))+\\b", "HAHEHI", text, perl = T)
  text <- gsub("\\b((l+)(a+))+\\b", "LALALA", text, perl = T)
  text <- gsub("(w+)(o+)(h+)(o+)", "WOHOO", text, perl = T)
  text <- gsub("\\b(d?(u+)(n+)?(h+))\\b", "UUUHHH", text, perl = T)
  text <- gsub("\\b(a+)(r+)(g+)(h+)\\b", "ARGH", text, perl = T)
  text <- gsub("\\b(a+)(w+)(h+)\\b", "AAAWWHH", text, perl = T)
  text <- gsub("\\b(p+)(s+)(h+)\\b", "SHHHHH", text, perl = T)
  text <- gsub("\\b((s+)(e+)?(h+))+\\b", "SHHHHH", text, perl = T)
  text <- gsub("\\b(s+)(o+)\\b", "", text, perl = T)
  text <- gsub("\\b(h+)(m+)\\b", "HHMM", text, perl = T)
  text <- gsub("\\b((b+)(l+)(a+)(h+)?)+\\b", "BLABLA", text, perl = T)
  text <- gsub("\\b((y+)(e+)(a+)(h+)?)+\\b", "YEAH", text, perl = T)
  text <- gsub("\\b((z+)?(o+)(m+)(f+)?(g+))+\\b", "OMG", text, perl = T)
  text <- gsub("aa(a+)", "a", text, perl = T)
  text <- gsub("ee(e+)", "e", text, perl = T)
  text <- gsub("i(i+)", "i", text, perl = T)
  text <- gsub("oo(o+)", "o", text, perl = T)
  text <- gsub("uu(u+)", "u", text, perl = T)
  text <- gsub("\\b(u(u+))\\b", "u", text, perl = T)
  text <- gsub("y(y+)", "y", text, perl = T)
  text <- gsub("hh(h+)", "h", text, perl = T)
  text <- gsub("gg(g+)", "g", text, perl = T)
  text <- gsub("tt(t+)\\b", "t", text, perl = T)
  text <- gsub("(tt(t+))", "tt", text, perl = T)
  text <- gsub("mm(m+)", "m", text, perl = T)
  text <- gsub("ff(f+)", "f", text, perl = T)
  text <- gsub("cc(c+)", "c", text, perl = T)
  text <- gsub("\\b(kkk)\\b", "KKK", text, perl = T)
  text <- gsub("\\b(pkk)\\b", "PKK", text, perl = T)
  text <- gsub("kk(k+)", "kk", text, perl = T)
  text <- gsub("fukk", "fuck", text, perl = T)
  text <- gsub("k(k+)\\b", "k", text, perl = T)
  text <- gsub("f+u+c+k+\\b", "fuck", text, perl = T)
  #gsub("((a+)|(h+)){3,}", "", "ishahahah hanibal geisha")
  text <- gsub("((a+)|(h+)){3,}", "HAHEHI", text, perl = T)
  
  text <- gsub("yeah", "YEAH", text, perl = T)
  # remove modified text
  #gsub("(?<=\\b\\w)\\s(?=\\w\\b)", "", "f u c k  y o u  a s  u  a r e  a  b i t c h  a s s  n i g g e r", perl = T)
  #gsub("(?<=\\b\\w)\\s(?=\\w\\b)", "", "n i g g e r f a g g o t", perl = T)
  text <- gsub("(?<=\\b\\w)\\s(?=\\w\\b)", "", text, perl = T)
  
  
  # remove stopwords
  otherstopwords <- c("put", "far", "bit", "well", "still", "much", "one", "two", "don", "now", "even", 
                      #"article", "articles", "edit", "edits", "page", "pages",
                      #"talk", "editor", "ax", "edu", "subject", "lines", "like", "likes", "line",
                      "uh", "oh", "also", "get", "just", "hi", "hello", "ok", "ja", #"editing", "edited",
                      "dont", "wikipedia", "hey", "however", "id", "yeah", "yo", 
                      #"use", "need", "take", "give", "say", "user", "day", "want", "tell", "even", 
                      #"look", "one", "make", "come", "see", "said", "now",
                      "wiki", 
                      #"know", "talk", "read", "time", "sentence", 
                      "ain't", "wow", #"image", "jpg", "copyright",
                      "wikiproject", #"background color", "align", "px", "pixel",
                      "org", "com", "en", "ip", "ip address", "http", "www", "html", "htm",
                      "wikimedia", "https", "httpimg", "url", "urls", "utc", "uhm",
                      #"i", "me", "my", "myself", "we", "our", "ours", "ourselves",
                      #"you", "your", "yours", "yourself", "yourselves", 
                      "he", "him", "his", "himself", 
                      "she", "her", "hers", "herself", 
                      "it", "its", "itself",    
                      #"they", "them", "their", "theirs", "themselves",
                      #"i'm", "you're", "he's", "i've", "you've", "we've", "we're",
                      #"she's", "it's", "they're", "they've", 
                      #"i'd", "you'd", "he'd", "she'd", "we'd", "they'd", 
                      #"i'll", "you'll", "he'll", "she'll", "we'll", "they'll",
                      "what", "which", "who", "whom", "this", "that", "these", "those",
                      #"am", "can", "will", "not",
                      "is", "was", "were", "have", "has", "had", "having", "wasn't", "weren't", "hasn't",
                      #"are", "cannot", "isn't", "aren't", "doesn't", "don't", "can't", "couldn't", "mustn't", "didn't",    
                      "haven't", "hadn't", "won't", "wouldn't",  
                      "do", "does", "did", "doing", "would", "should", "could",  
                      "be", "been", "being", "ought", "shan't", "shouldn't", "let's", "that's", "who's", "what's", "here's",
                      "there's", "when's", "where's", "why's", "how's", "a", "an", "the", "and", "but", "if",
                      "or", "because", "as", "until", "while", "of", "at", "by", "for", "with", "about", "against",
                      "between", "into", "through", "during", "before", "after", "above", "below", "to", "from",
                      "up", "down", "in", "out", "on", "off", "over", "under", "again", "further", "then", "once",
                      "here", "there", "when", "where", "why", "how", "all", "any", "both", "each", "few", "more",
                      "most", "other", "some", "such", "no", "nor", "only", "own", "same", "so", "than",
                      "too", "very")
  #is.element(otherstopwords, stopwords("en"))
  text <- removeWords(text, otherstopwords)
  
  # remove nicknames
  #gsub("@\\w+", " ", "@nana, das @ ist ein @spieler")
  text <- gsub("@\\w+", " ", text, perl = T)
  
  # remove graphics
  text <- gsub("[^[:graph:]]", " ", text, perl = T)
  # remove punctuation
  text <- gsub("[[:punct:]]", " ", text, perl = T)
  # remove digits
  text <- gsub("[[:digit:]]", " ", text, perl = T)
  # strip multiple whitspace to one
  text <- gsub("\\s+", " ", text, perl = T)
  
  #gsub("((a+)|(h+))(a+)((h+)?)\\b", "", "explanation hardcore aaaaaaahhhhhhhhh hhhaaaaaah haaaaaaah aaaaaaaa haaaa")
  #text <- gsub("((a+)|(h+))(a+)((h+)?)\\b", "", text, perl = T)
  
  text <- gsub("((lol)(o?))+\\b", "LOL", text, perl = T)
  text <- gsub("n ig ger", "nigger", text, perl = T)
  text <- gsub("nig ger", "nigger", text, perl = T)
  text <- gsub("s hit", "shit", text, perl = T)
  text <- gsub("g ay", "gay", text, perl = T)
  text <- gsub("f ag got", "faggot", text, perl = T)
  text <- gsub("c ock", "cock", text, perl = T)
  text <- gsub("cu nt", "cunt", text, perl = T)
  text <- gsub("idi ot", "idiot", text, perl = T)
  text <- gsub("(?<=\\b(fu|su|di|co|li))\\s(?=(ck)\\b)", "", text, perl = T)
  #gsub("(?<=\\w(ck))\\s(?=(ing)\\b)", "", "fuck ing suck ing lick ing", perl = T)
  text <- gsub("(?<=\\w(ck))\\s(?=(ing)\\b)", "", text, perl = T)
  
  # reomve single letters
  #gsub("\\W*\\b\\w\\b\\W*", " ", "er i das auto ist kaputt 5 6")
  #text <- gsub("\\W*\\b\\w\\b\\W*", " ", text, perl = T)
  
  text <- gsub("\\b(.)\\1+\\b", " ", text, perl = T)
  
  # again clean shittext
  text <- gsub("((lol)(o?))+", "LOL", text, perl = T)
  text <- gsub("(?<=\\b(fu|su|di|co|li))\\s(?=(ck)\\b)", "", text, perl = T)
  text <- gsub("(?<=\\w(ck))\\s(?=(ing)\\b)", "", text, perl = T)
  text <- gsub("(?<=\\w(uc))\\s(?=(ing)\\b)", "", text, perl = T)
  #gsub("(?<=\\b(fu|su|di|co|li))\\s(?=(ck)\\w)", "", tolower(train_data[79644,]$comment_text), perl = T)
  text <- gsub("(?<=\\b(fu|su|di|co|li))\\s(?=(ck)\\w)", "", text, perl = T)
  text <- gsub("cocksu cking", "cock sucking", text, perl = T)
  text <- gsub("du mbfu ck", "dumbfuck", text, perl = T)
  text <- gsub("cu nt", "cunt", text, perl = T)
  text <- gsub("(?<=\\b(fu|su|di|co|li))\\s(?=(k)\\w)", "c", text, perl = T)
  
  # again remove stopwords
  text <- removeWords(text, otherstopwords)
  # strip multiple whitspace to one
  text <- gsub("\\s+", " ", text, perl = T)
  # remove tailing whitespaces
  text <- gsub("\\s*$", "", text, perl = T)
  # remove leading whitespaces
  text <- gsub("^\\s+", "", text, perl = T)
  
  text <- gsub("\\b(.)\\1+\\b", " ", text, perl = T)
  
  # remove single letter words but save "I"
  #gsub("\\W*\\b([a-h|j-z])\\b\\W*", " ", "er i das auto ist kaputt 5 6 i j k l m")
  text <- gsub("\\W*\\b([a-h|j-z])\\b\\W*", " ", text, perl = T)
  #text <- gsub("\\W*\\b\\w\\b\\W*", " ", text, perl = T)
  
  # again strip multiple whitspace to one
  text <- gsub("\\s+", " ", text, perl = T)
  # remove tailing whitespaces
  text <- gsub("\\s*$", "", text, perl = T)
  # remove leading whitespaces
  text <- gsub("^\\s+", "", text, perl = T)
  
  # reomve double words and sort alphabetically
  #text <- sapply(text, function(x){
  #  words <- unique(unlist(strsplit(x, split = " ")))
  #  paste(words[order(words)], collapse = " ")
  #})
  return(unname(text))
}

library(doParallel)

cat("Combining data for simpler custom text-transformation")
# combine datasets
test$toxic <- NA
test$severe_toxic <- NA
test$obscene <- NA
test$threat <- NA
test$insult <- NA
test$identity_hate <- NA

test$type <- "test"
train$type <- "train"

dataset <- rbind(train, test)


system.time(comment_text <- mcmapply(1:nrow(dataset), FUN =  function(x) {
  cleaning_texts(dataset$comment_text[x])},
  mc.cores = 3, mc.preschedule = TRUE))

dataset$comment_text <- comment_text
#dataset <- fread("./InputData/dataset_cleansing.csv", header = T, encoding = 'UTF-8')

##################################################
#### EDA
##################################################

fillColor = "#FFA07A"
fillColor2 = "#F1C40F"

##  Sentence Length Distribution

dataset$len = str_count(dataset$comment_text)
dataset %>%
  ggplot(aes(x = len, fill = type)) +    
  geom_histogram(alpha = 0.5, bins = 50) +
  labs(x= 'Word Length',y = 'Count', title = paste("Distribution of", ' Word Length ')) +
  theme_bw()

createBarPlotCommonWords = function(train,title)
{
  train %>%
    unnest_tokens(word, comment_text) %>%
    filter(!word %in% stop_words$word) %>%
    count(word,sort = TRUE) %>%
    ungroup() %>%
    mutate(word = factor(word, levels = rev(unique(word)))) %>%
    head(20) %>%
    
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

createBarPlotCommonWords(dataset,'Top 20 most Common Words')

trainWords <- filter(dataset, type == 'train') %>%
  unnest_tokens(word, comment_text) %>%
  count(toxic,severe_toxic,obscene,threat,insult,identity_hate,word) %>%
  ungroup()

total_words <- trainWords %>% 
  group_by(toxic,severe_toxic,obscene,threat,insult,identity_hate) %>% 
  summarize(total = sum(n))

total_words


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


## Various Categories of TF-IDF
# 1 Toxic TF-IDF
plot_trainWords %>%
  filter(toxic == 1 ) %>%
  top_n(20) %>%
  ggplot(aes(word, tf_idf)) +
  geom_col(fill = fillColor2) +
  labs(x = NULL, y = "tf-idf") +
  coord_flip() +
  theme_bw()
# 2 Severe Toxic TF-IDF
plot_trainWords %>%
  filter(severe_toxic == 1 ) %>%
  top_n(20) %>%
  ggplot(aes(word, tf_idf)) +
  geom_col(fill = fillColor2) +
  labs(x = NULL, y = "tf-idf") +
  coord_flip() +
  theme_bw()
# 3 Obscene TF-IDF
plot_trainWords %>%
  filter(obscene == 1 ) %>%
  top_n(20) %>%
  ggplot(aes(word, tf_idf)) +
  geom_col(fill = fillColor2) +
  labs(x = NULL, y = "tf-idf") +
  coord_flip() +
  theme_bw()
# 4 Threat TF-IDF
plot_trainWords %>%
  filter(threat == 1 ) %>%
  top_n(20) %>%
  ggplot(aes(word, tf_idf)) +
  geom_col(fill = fillColor2) +
  labs(x = NULL, y = "tf-idf") +
  coord_flip() +
  theme_bw()
# 5 Insult TF-IDF
plot_trainWords %>%
  filter(insult == 1 ) %>%
  top_n(20) %>%
  ggplot(aes(word, tf_idf)) +
  geom_col(fill = fillColor2) +
  labs(x = NULL, y = "tf-idf") +
  coord_flip() +
  theme_bw()
# 6 identity_hate TF-IDF
plot_trainWords %>%
  filter(identity_hate == 1 ) %>%
  top_n(20) %>%
  ggplot(aes(word, tf_idf)) +
  geom_col(fill = fillColor2) +
  labs(x = NULL, y = "tf-idf") +
  coord_flip() +
  theme_bw()
##  Word Cloud for the Most Important Words
plot_trainWords %>%
  with(wordcloud(word, tf_idf, max.words = 50,colors=brewer.pal(8, "Dark2")))

