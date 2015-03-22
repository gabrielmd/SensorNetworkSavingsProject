
# This is the server logic for a Shiny web application.
# You can find out more about building applications with Shiny here:
#
# http://shiny.rstudio.com
#

library(shiny)
library(shinydashboard)
library(ggplot2)

shinyServer(function(input, output, session) {  

        output$tabSetPanelUI <- renderUI({
                input$calculate
                
                myTabs <- list(tabPanel("Sensors in the lab", 

                                        h2("How to use this application"),
                                        p("The data used in this application was produced by temperature sensors placed in a laboratory.
                                        The following figure shows their positions inside the room."),
                                        img(src = "lab.png", alt = "Lab with sensors", height="308", width="600"),
                                        p("Given that these sensors are powered by batteries, one may decide to turn some of them off in 
                                          order to save their energy. Therefore, we want to predict the measurements that 
                                          a sensor will make in a day, based on the measurements from the other sensors.
                                          In the menu, you can adjust the accepted error (in degrees Celsius), set
                                          which node you are planning to turn off and choose which of them you will use to 
                                          predict its measurements.
                                          The application will make the predictions for one day and verify if they fall inside the
                                          accepted threshold."),
                                        p("Source of the data: ", a("http://db.lcs.mit.edu/labdata/labdata.html"))
                                )
                        )

                if(input$calculate > 0) {
                        myTabs[[2]] <- tabPanel("Summary of predictions", plotOutput("plotPredictions"), textOutput("recommendation"))
                }
                
                do.call(tabsetPanel, c(id = "tabSetPanel", myTabs))
        })
        
        # Sensor to predict
        output$sensorToPredictSelect <- renderUI({
                if(!exists("wsn.data")){
                        wsn.data <<- read.wsn.data()
                }
                sensorNums <- sort(unique(wsn.data$V4))
                # Add names, so that we can add all=0
                names(sensorNums) <- sensorNums
                selectInput("predictedSensor", "Sensor to predict", choices = sensorNums, selected = sensorNums[1])
        })
        
        output$sensorToUseSelect <- renderUI({
                if(!exists("wsn.data")){
                        wsn.data <<- read.wsn.data()
                }
                sensorNums <- sort(unique(wsn.data$V4))
                # Add names, so that we can add all=0
                names(sensorNums) <- sensorNums
                selectInput("sensorToUse", "Sensor(s) to use", multiple = TRUE, choices = sensorNums, selected = sensorNums[2:3])
        })     
        
        observe({
                if(input$calculate > 0) {
                        
                        updateTabsetPanel(session, "tabSetPanel", selected = "Summary of predictions")
                        
                        predictionOutcomes <- isolate({
                                withProgress(message = 'Loading', value = 0, {
                                        # Increment the progress bar, and update the detail text.
                                        incProgress(0.01, detail = "Loading data")
                                        if(!exists("training") || !exists("testing")){
                                                loaded.data <- load.data()
                                                training <<- loaded.data$training
                                                testing <<- loaded.data$testing
                                        }
                                        # Increment the progress bar, and update the detail text.
                                        incProgress(0.5, detail = "Generating predictions")
                                        fun.prediction(training, testing, input$predictedSensor, input$sensorToUse)
                                })
                        })
                       
                        predictedSensor <- isolate({ input$predictedSensor })
                        sensorToUse <- isolate({ input$sensorToUse })
                        
                        output$plotPredictions <- renderPlot({
                                plot.prediction(input$acceptedThreshold, predictedSensor, sensorToUse, predictionOutcomes)
                        })
                        
                        output$recommendation <- renderText({
                                text.suffix <- paste0("use this set of sensors (", paste(sensorToUse, collapse = ",") , ") to predict the values of the sensor ", input$predictedSensor, ", if the maximum accepted error is (+/-) ", input$acceptedThreshold, "ºC")
                                if(test.accuracy(input$acceptedThreshold, predictedSensor, sensorToUse, predictionOutcomes)){
                                        paste0("Recommended! You should ", text.suffix)
                                }else{
                                        paste0("You should NOT ", text.suffix)
                                }
                        })
                }
        })
})



