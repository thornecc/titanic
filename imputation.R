library('dplyr')
library('magrittr')
library('pryr')
library('readr')
library('rpart')
library('rattle')
library('rpart.plot')
library('RColorBrewer')

OutputFile <- function(name, ext, dir='out') {
  file.path(dir, paste0(name, '.', ext))
}

PlotWrite <- function(x, name) {
  pdf(OutputFile(name=name, ext='pdf'))
  fancyRpartPlot(x)
  dev.off()
}

PredictWrite <- function(tree, name, newdata=test) {
  prediction <- predict(tree, newdata=newdata, type='class')
  submission <- data.frame(PassengerId=test$PassengerId, Survived=prediction)
  write.csv(submission, file=OutputFile(name=name, ext='csv'), row.names=F, quote=F)
  prediction
}

# generate rpart decision tree model with default options
Model <- function(name, equation, data, newdata=test) {
  tree <- rpart(equation, data=data, method='class')
  PlotWrite(tree, name)
  prediction <- PredictWrite(tree, name, newdata=newdata)
  list(name=name, tree=tree, prediction=prediction)
}

# specialisations of above with particular equations, i.e. factors specified
SimpleModel <- partial(Model, equation=(Survived ~ Sex + Age + Pclass))
ComplexModel <- partial(Model, equation=(Survived ~ Sex + Age + Pclass + Parch + SibSp + Fare))

# load training and test data
train <- read_csv('train.csv')
test <- read_csv('test.csv')

# create output dir if it doesn't exist yet
dir.create('out', showWarnings=F)

## Basic Model
#
# Factors: sex, age, passenger class
# Imputation: none
# Kaggle Score: 0.73684
model.sex.age.pclass <- SimpleModel(data=train, name='model.sex.age.pclass')

## More complex model
#
# Factors: sex, age, passenger class, parents/children, siblings/spouses, fare
# Imputation: none
# Kaggle Score: 0.79426
model.sex.age.pclass.parch.sibsp.fare <- ComplexModel(data = train, name = 'model.sex.age.pclass.parch.sibsp.fare')

# training data with average imputed age
average.age <- mean(train$Age, na.rm = TRUE)
train.average.age <- train
train.average.age %<>% mutate(Age = ifelse(is.na(Age), average.age, Age))

## Simple model, average imputation (train data only)
#
# Factors: sex, age, passenger class
# Imputation: age (average on train only)
# Kaggle Score: 0.73684
# (exactly the same as non imputed)
model.sex.age.pclass.impute.average.age.train.only <- SimpleModel(data = train.average.age, name = 'model.sex.age.pclass-imputed.average.age.train.only')

# test data with average imputed age
test.average.age <- test
test.average.age %<>% mutate(Age = ifelse(is.na(Age), average.age, Age))

## Simple model, average imputation (including test data)
#
# Factors: sex, age, passenger class
# Imputation: age (average on train and test data)
# Kaggle Score: 0.73684
# (exactly the same as non imputed)
model.sex.age.pclass.impute.average.age <- SimpleModel(data = train.average.age, newdata = test.average.age, name = 'model.sex.age.pclass-imputed.average.age')

## Complex model, average imputation
#
# Factors: sex, age, passenger class, parents/children, siblings/spouses, fare
# Imputation: age (average)
# Kaggle Score: 0.77990
model.sex.age.pclass.parch.sibsp.fare.impute.average.age <- ComplexModel(data = train.average.age, newdata = test.average.age, name = 'model.sex.age.pclass.parch.sibsp.fare-imputed.average.age')

# linear model for age imputation
age.model <- lm(Age ~ SibSp + Sex + Pclass, train)
train.age.prediction <- predict(age.model, train)
test.age.prediction <- predict(age.model, test)

# linear model imputed training data
train.lm.age <- train
train.lm.age$Age[is.na(train$Age)] = train.age.prediction[is.na(train$Age)]

# linear model imputed test data
# Kaggle score: 0.77033
test.lm.age <- test
test.lm.age$Age[is.na(test$Age)] = test.age.prediction[is.na(test$Age)]
model.sex.age.pclass.parch.sibsp.fare.impute.lm.age <- ComplexModel(data = train.lm.age, newdata = test.lm.age, name = 'model.sex.age.pclass.parch.sibsp.fare.impute.lm.age')

# tree4 is not defined -- can't remember what this bit was doing, so commented it out for now
#Prediction4 <- predict(tree4, newdata=test, type = 'class')
#submit4 <- data.frame(PassengerId = test$PassengerId, Survived = Prediction4)
#write.csv(submit4, file = "tree.age.lm.csv", row.names = FALSE)
