rm( list=ls() )  #remove all objects
gc()       
library(xgboost)
install.packages("shapr")
library(shapr)

premier <- read.csv("/Users/dfontenla/Maestria/2022C2/EEA/practica/repo/EEA-2022/TP2/fifa/Premier2017-2022 - CURADO.csv", encoding = "UTF-8")

y_var <- "FTR"
x_var <- c("HS",	"AS",	"HST",	"AST",	"HF",	"AF",	"HC",	"AC",	"HY",	"AY",	"HR",	"AR")

x_train <- as.matrix(premier[-1:-6, x_var])
y_train <- premier[-1:-6, y_var]
x_test <- as.matrix(premier[1:6, x_var])

# Fitting a basic xgboost model to the training data
model <- xgboost(
  data = x_train,
  label = y_train,
  nround = 20,
  verbose = FALSE
)

# Prepare the data for explanation
explainer <- shapr(x_train, model)
#> The specified model provides feature classes that are NA. The classes of data are taken as the truth.

# Specifying the phi_0, i.e. the expected prediction without any features
p <- mean(y_train)

str(x_test)
# Computing the actual Shapley values with kernelSHAP accounting for feature dependence using
# the empirical (conditional) distribution approach with bandwidth parameter sigma = 0.1 (default)
explanation <- explain(
  x_test,
  approach = "empirical",
  explainer = explainer,
  prediction_zero = p
)

# Printing the Shapley values for the test data.
# For more information about the interpretation of the values in the table, see ?shapr::explain.
print(explanation$dt)
#>      none     lstat         rm       dis      indus
#> 1: 22.446 5.2632030 -1.2526613 0.2920444  4.5528644
#> 2: 22.446 0.1671903 -0.7088405 0.9689007  0.3786871
#> 3: 22.446 5.9888016  5.5450861 0.5660136 -1.4304350
#> 4: 22.446 8.2142203  0.7507569 0.1893368  1.8298305
#> 5: 22.446 0.5059890  5.6875106 0.8432240  2.2471152
#> 6: 22.446 1.9929674 -3.6001959 0.8601984  3.1510530

# Plot the resulting explanations for observations 1 and 6
plot(explanation, plot_phi0 = FALSE, index_x_test = c(1, 6))
x_test
y_test <- premier[1:6, y_var]
y_test
plot(explanation, plot_phi0 = FALSE)

# Use the Gaussian approach
explanation_gaussian <- explain(
  x_test,
  approach = "gaussian",
  explainer = explainer,
  prediction_zero = p
)

# Plot the resulting explanations for observations 1 and 6
plot(explanation_gaussian, plot_phi0 = FALSE, index_x_test = c(1, 6))


# Use the Gaussian copula approach
explanation_copula <- explain(
  x_test,
  approach = "copula",
  explainer = explainer,
  prediction_zero = p
)

# Plot the resulting explanations for observations 1 and 6, excluding
# the no-covariate effect
plot(explanation_copula, plot_phi0 = FALSE, index_x_test = c(1, 6))

install.packages("partykit")
library("partykit")
# Use the conditional inference tree approach
explanation_ctree <- explain(
  x_test,
  approach = "ctree",
  explainer = explainer,
  prediction_zero = p
)

# Plot the resulting explanations for observations 1 and 6, excluding 
# the no-covariate effect
plot(explanation_ctree, plot_phi0 = FALSE, index_x_test = c(1, 6))

# We can use mixed (i.e continuous, categorical, ordinal) data with ctree. Use ctree with categorical data in the following manner:

x_var_cat <- c("lstat", "chas", "rad", "indus")
y_var <- "medv"

# convert to factors
Boston$rad = as.factor(Boston$rad)
Boston$chas = as.factor(Boston$chas)

x_train_cat <- Boston[-1:-6, x_var_cat]
y_train <- Boston[-1:-6, y_var]
x_test_cat <- Boston[1:6, x_var_cat]

# -- special function when using categorical data + xgboost
dummylist <- make_dummies(traindata = x_train_cat, testdata = x_test_cat)

x_train_dummy <- dummylist$train_dummies
x_test_dummy <- dummylist$test_dummies

# Fitting a basic xgboost model to the training data
model_cat <- xgboost::xgboost(
  data = x_train_dummy,
  label = y_train,
  nround = 20,
  verbose = FALSE
)
model_cat$feature_list <- dummylist$feature_list

explainer_cat <- shapr(dummylist$traindata_new, model_cat)

p <- mean(y_train)

explanation_cat <- explain(
  dummylist$testdata_new,
  approach = "ctree",
  explainer = explainer_cat,
  prediction_zero = p
)

# Plot the resulting explanations for observations 1 and 6, excluding
# the no-covariate effect
plot(explanation_cat, plot_phi0 = FALSE, index_x_test = c(1, 6))

# Use the conditional inference tree approach
# We can specify parameters used to building trees by specifying mincriterion, 
# minsplit, minbucket

explanation_ctree <- explain(
  x_test,
  approach = "ctree",
  explainer = explainer,
  prediction_zero = p,
  mincriterion = 0.80, 
  minsplit = 20,
  minbucket = 20
)

# Default parameters (based on (Hothorn, 2006)) are:
# mincriterion = 0.95
# minsplit = 20
# minbucket = 7

# Use the conditional inference tree approach
# Specify a vector of mincriterions instead of just one
# In this case, when conditioning on 1 or 2 features, use mincriterion = 0.25
# When conditioning on 3 or 4 features, use mincriterion = 0.95

explanation_ctree <- explain(
  x_test,
  approach = "ctree",
  explainer = explainer,
  prediction_zero = p,
  mincriterion = c(0.25, 0.25, 0.95, 0.95)
)



#### shapr currently natively supports explanation of predictions from models fitted with the following functions:

install.packages("gbm")
library(gbm)
#> Loaded gbm 2.1.5

xy_train <- data.frame(x_train,medv = y_train)

form <- as.formula(paste0(y_var,"~",paste0(x_var,collapse="+")))

# Fitting a gbm model
set.seed(825)
model <- gbm::gbm(
  form,
  data = xy_train,
  distribution = "gaussian"
)

#### Full feature versions of the three required model functions ####

predict_model.gbm <- function(x, newdata) {
  
  if (!requireNamespace('gbm', quietly = TRUE)) {
    stop('The gbm package is required for predicting train models')
  }

  model_type <- ifelse(
    x$distribution$name %in% c("bernoulli","adaboost"),
    "classification",
    "regression"
  )
  if (model_type == "classification") {

    predict(x, as.data.frame(newdata), type = "response",n.trees = x$n.trees)
  } else {

    predict(x, as.data.frame(newdata),n.trees = x$n.trees)
  }
}

get_model_specs.gbm <- function(x){
  feature_list = list()
  feature_list$labels <- labels(x$Terms)
  m <- length(feature_list$labels)

  feature_list$classes <- attr(x$Terms,"dataClasses")[-1]
  feature_list$factor_levels <- setNames(vector("list", m), feature_list$labels)
  feature_list$factor_levels[feature_list$classes=="factor"] <- NA # the model object doesn't contain factor levels info

  return(feature_list)
}

# Prepare the data for explanation
set.seed(123)
explainer <- shapr(xy_train, model)
#> The columns(s) medv is not used by the model and thus removed from the data.
p0 <- mean(xy_train[,y_var])
explanation <- explain(x_test, explainer, approach = "empirical", prediction_zero = p0)
# Plot results
plot(explanation)

