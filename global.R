library(reshape)
library(caret)
library(randomForest)

## functions used for accessing the data
download.wsn.data <- function(){
        download.file("http://db.lcs.mit.edu/labdata/data.txt.gz", destfile = "data_wsn.txt.gz")
}


read.wsn.data <- function(days = c("2004-02-28", "2004-03-01")){ #, "2004-03-02", "2004-03-03", "2004-03-04", "2004-03-05", "2004-03-06", "2004-03-07", "2004-03-08", "2004-03-09", "2004-03-12", "2004-03-13", "2004-03-14", "2004-03-17", "2004-03-19", "2004-03-20")){
        if(!file.exists("wsn.data.rds")){
        
                # download the data, if needed
                if(!file.exists("data_wsn.txt.gz")){
                        download.wsn.data()
                }
                
                wsn.data <- read.table("data_wsn.txt.gz", sep=' ')
                
                # dates with good data
                wsn.data.tidy <- subset(wsn.data, (V1 %in% days))
                # complete cases only
                wsn.data.tidy <- wsn.data.tidy[complete.cases(wsn.data.tidy),]
                
                saveRDS(wsn.data.tidy, "wsn.data.rds")
        }else{
                wsn.data <- readRDS("wsn.data.rds")
                wsn.data.tidy <- subset(wsn.data, (V1 %in% days))
        }
        wsn.data.tidy
}

prepare.data <- function(day = "2004-02-28"){
        wsn.data <- read.wsn.data(day)
        temperature.data <- cast(wsn.data, V3~V4, function(e){ if(length(e) != 1){ NA }else{ e[1] } } , value = "V5")
        
        for(i in 2:nrow(temperature.data)){
                temperature.data[i, is.na(temperature.data[i, ])] <- temperature.data[(i-1), is.na(temperature.data[i, ])]
        }
        
        names(temperature.data) <- make.names(names(temperature.data))
        temperature.data
}

load.data <- function(){
        training.file.name <- "training.rds"
        if(!file.exists(training.file.name)){
                training.data <- prepare.data("2004-02-28")
                saveRDS(training.data, file = training.file.name)
        }else{
                training.data <- readRDS(training.file.name)
        }
        trainIndex <- createDataPartition(training.data$V3, p=0.05, list = FALSE)
        training.data <- training.data[trainIndex,]
        
        testing.file.name <- "testing.rds"
        if(!file.exists(testing.file.name)){
                testing.data <- prepare.data("2004-03-01")
                saveRDS(testing.data, file = testing.file.name)
        }else{
                testing.data <- readRDS(testing.file.name)
        }
        list(training = training.data, testing = testing.data)
}

fit.model <- function(training, predicted.node, using.nodes){
        using.cols <- paste0("X", using.nodes)
        predicted.node.col <- paste0("X", predicted.node)
        
        training.local <- training[complete.cases(training[ , c(predicted.node.col, using.cols)]), c(predicted.node.col, using.cols)]
        (fmla <- as.formula(paste(predicted.node.col, "~", paste(using.cols, collapse= "+"))))
        fit <- train(fmla, 
                     data = training.local, 
                     method="rf",
                     prox=TRUE,
                     allowParallel=TRUE, 
                     trControl=trainControl(method = "cv", number = 2 ),
                     tuneGrid = data.frame(.mtry = 2))
        
        fit
}

fun.prediction <- function(training, testing, predicted.node, using.nodes){
        if(predicted.node %in% using.nodes){
                using.nodes <- using.nodes[which(using.nodes != predicted.node)]
        }

        fit <- fit.model(training, predicted.node, using.nodes)
        
        using.cols <- paste0("X", using.nodes)
        predicted.node.col <- paste0("X", predicted.node)
        testing.data <- testing[complete.cases(testing[, c(predicted.node.col, using.cols)]), ]
        
        predict(fit, newdata = testing.data[, using.cols, drop = FALSE])
}

plot.prediction <- function(accepted.error, predicted.node, using.nodes, outcomes){
        using.cols <- paste0("X", using.nodes)
        predicted.node.col <- paste0("X", predicted.node)
        testing.data <- testing[complete.cases(testing[ , c(predicted.node.col, using.cols)]), ]
        
        df <- data.frame(x = testing.data$V3, y = testing.data[,predicted.node.col], type="real observation", group = 1)
        df <- rbind(df, data.frame(x = testing.data$V3[complete.cases(testing[ , c(predicted.node.col, using.cols)])], y = outcomes, type="prediction", group = 2))
        df <- rbind(df, data.frame(x = testing.data$V3, y = testing.data[,predicted.node.col]+accepted.error, type="accepted threshold", group = 3))
        df <- rbind(df, data.frame(x = testing.data$V3, y = testing.data[,predicted.node.col]-accepted.error, type="accepted threshold", group = 4))
        
        ggplot(df, aes(x, y, group = group, col = type)) + geom_line() + xlab("Time") + ylab("Temperature (ºC)")
}

test.accuracy <- function(accepted.error, predicted.node, using.nodes, outcomes){
        using.cols <- paste0("X", using.nodes)
        predicted.node.col <- paste0("X", predicted.node)
        testing.data <- testing[complete.cases(testing[ , c(predicted.node.col, using.cols)]), ]

        (sum(abs(outcomes - testing.data[, predicted.node.col]) > accepted.error) == 0)
}

