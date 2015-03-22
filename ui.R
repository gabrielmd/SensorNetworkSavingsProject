library(shiny)
library(shinydashboard)

header <- dashboardHeader(
        title = "Planning savings"
)

body <- dashboardBody(
        tags$head(
                tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
        ),
        fluidRow(
                column(width = 9,
                       box(width = NULL, solidHeader = TRUE, id="boxContent",
                           uiOutput("tabSetPanelUI")
                       )
                ),
                column(width = 3,
                       box(width = NULL, status = "warning",
                           uiOutput("sensorToPredictSelect"),
                           uiOutput("sensorToUseSelect"),
                           p(
                                   class = "text-muted",
                                   paste("Note: You can select more than one sensor to be activated.
                                         The sensor selected to be predicted will 
                                         be automatically removed from the list of sensors in use."
                                   )
                           ),
                           actionButton("calculate", "Try this plan!")
                       ),
                       box(width = NULL, status = "warning",
                           sliderInput("acceptedThreshold", "Maximum error threshold (in ºC):", min = 0.01, max = 2,
                                       value = 0.2, step = 0.01)
                       )
                )
        )
)

dashboardPage(
        header,
        dashboardSidebar(disable = TRUE),
        body
)
