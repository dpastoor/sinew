#' @title Interactive add-in
#' @description Launches an interactive addin for insertion of roxygen2 comments in files.
#' Allows selection of extra parameters for \code{makeOxygen}
#' @return Nothing. Inserts roxygen2 comments in a file opened in the source editor.
#' @author Anton Grishin, Jonathan Sidi
#' @details Open an .R file in Rstudio's source editor.
#' Launch the add-in via Addins -> interactiveOxygen or interOxyAddIn() in the console.
#' Add-in opens in the viewer panel.
#' Select function's/dataset's name in the source editor.
#' If objects cannot be found, the addin prompts to source the file.
#' Choose parameters for \code{makeOxygen}. Click Insert.
#' Select next object's name. Rinse.Repeat. Click Quit when done with the file.
#' @examples
#' interOxyAddIn() # launches interactive add-in, alternatively,
#' Rstudio menu Addins -> 'interactiveOxygen' 
#' @export 
#' @rdname interOxyAddIn
#' @seealso \code{View(sinew:::oxygenAddin)}
#' @import rstudioapi
#' @import shiny
#' @import miniUI
interOxyAddIn <- function() {
  
  #on.exit(detach("interOxyEnvir"))
  
  tweaks <- 
    list(tags$head(tags$style(HTML("
                                   .multicol { 
                                   height: 300px;
                                   -webkit-column-count: 3; /* Chrome, Safari, Opera */ 
                                   -moz-column-count: 3;    /* Firefox */ 
                                   column-count: 3; 
                                   -moz-column-fill: auto;
                                   -column-fill: auto;
                                   } 
                                   ")) 
    ))
  
  header_add = c(author = "AUTHOR [AUTHOR_2]", backref = "src/filename.cpp", 
                 concept = "CONCEPT_TERM_1 [CONCEPT_TERM_2]", describeIn = "FUNCTION_NAME DESCRIPTION", 
                 details = "DETAILS", example = "path_to_file/relative/to/packge/root", 
                 examples = "\n#' \\dontrun{\n#' if(interactive()){\n#'  #EXAMPLE1\n#'  }\n#' }", 
                 export = "", family = "FAMILY_TITLE", field = "FIELD_IN_S4_RefClass DESCRIPTION", 
                 format = "DATA_STRUCTURE", importClassesFrom = "PKG CLASS_a [CLASS_b]", 
                 importMethodsFrom = "PKG METHOD_a [METHOD_b]", include = "FILENAME.R [FILENAME_b.R]", 
                 inherit = "[PKG::]SOURCE_FUNCTION [FIELD_a FIELD_b]", 
                 inheritDotParams = "[PKG::]SOURCE_FUNCTION", inheritSection = "[PKG::]SOURCE_FUNCTION [SECTION_a SECTION_b]", 
                 keywords = "KEYWORD_TERM", name = "NAME", rdname = "FUNCTION_NAME", 
                 references = "BIB_CITATION", section = "SECTION_NAME", 
                 source = "\\url{http://somewhere.important.com/}", slot = "SLOTNAME DESCRIPTION", 
                 template = "FILENAME", templateVar = "NAME VALUE", useDynLib = "PKG [ROUTINE_a ROUTINE_b]")
  
  controls<-list(h3("Select Fields to add to Oxygen Output"),
                 tags$div(align = 'left', 
                          class = 'multicol',
                          checkboxGroupInput(inputId = "fields",
                                             label = '',
                                             choices = names(header_add),
                                             selected = c("examples", "details", "seealso", "export", "rdname")))
  )
  
  ui <- miniUI::miniPage(
    tweaks,
    miniUI::gadgetTitleBar(textOutput("title", inline = TRUE),
                           left = miniUI::miniTitleBarButton( "qt", "Quit"),
                           right = miniUI::miniTitleBarButton(inputId = "insrt","Insert",
                                                              primary = TRUE)),
    miniUI::miniContentPanel(
      sidebarLayout(sidebarPanel = sidebarPanel(
        radioButtons(inputId = 'action',label = 'Action',
                     choices = c('Create','Update'),
                     selected = 'Create',inline = TRUE),
        controls,
        hr(style = "border-top: 3px solid #cccccc;"),
        sliderInput(inputId = "cut", label = "cut", value = 0,
                    min = 0, max = 20, step = 1, ticks = FALSE),
        br(),
        uiOutput("cutslider"),
        br(),width = 5 
      ),
      mainPanel = mainPanel(
        verbatimTextOutput('preview'),width=7
      ))
    )
  )
  
  server <- function(input, output, session) {
    
    output$title <- renderText({paste0("Select parameters in makeOxygen(\"",robj()$selection[[1]]$text,  "\"...)")})
    observeEvent(input$no, stopApp())
    rfile <- reactiveVal()
    output$dictfile <- renderText({rfile()})
    
    output$cutslider <- renderUI({if (dir.exists("./man-roxygen")) {
      div(div(actionLink("butt", "use_dictionary",
                         icon = icon("folder-open", "glyphicons")),
              textOutput("dictfile")), hr())
    } else {p()}
    })
    
    robj <- reactivePoll(1000, session,
                         checkFunc = rstudioapi::getActiveDocumentContext,
                         valueFunc = rstudioapi::getActiveDocumentContext
    )
    
    observeEvent(robj(), {
      path <- robj()$path
      obj <- robj()$selection[[1]]$text
      
      if (!nzchar(path)) {
        showModal(modalDialog(
          title = HTML(paste0("Open an .R file in the source editor and ",
                              "<strong><u>select</u></strong> object's name!")),
          easyClose = TRUE)
        )
      }
      
      if (nzchar(obj) && is.null(get0(obj)) && !"interOxyEnvir" %in% search()) {
        showModal(modalDialog(title = paste(dQuote(obj), "not found!",
                                            "Do you want to source", 
                                            basename(rstudioapi::getSourceEditorContext()$path),
                                            " file or quit add-in?"),
                              footer = tagList(actionButton("no", "Quit Add-in"),
                                               actionButton("ok","Source"))
        ))}
      
    })
    
    observeEvent(input$qt, {
      if ("interOxyEnvir" %in% search()) detach("interOxyEnvir"); stopApp()})
    
    observeEvent(input$ok, {
      nenv <- attach(NULL, name = "interOxyEnvir")
      sys.source(rstudioapi::getSourceEditorContext()$path, nenv,
                 keep.source = TRUE)
      removeModal()
    })
    
    observeEvent(input$butt, {
      hh <- NULL
      try(hh <- file.choose(), silent = TRUE)
      rfile(hh)})
    
    observeEvent(input$insrt, {
      obj <- robj()$selection[[1]]$text
      if (!nzchar(obj) ||
          (is.null(get0(obj)) && "interOxyEnvir" %in% search())) {
        showModal(modalDialog(
          tags$h4(style = "color: red;","Make valid object selection!"),
          size = "s", easyClose = TRUE)
        )
      } else {
        ctxt <- rstudioapi::getSourceEditorContext()
        params <- list(obj = obj,
                       add_fields = input$fields,
                       add_default = TRUE,
                       print = FALSE,
                       use_dictionary = rfile(),
                       cut = input$cut
        )
        ins_txt <- do.call(sinew::makeOxygen, params)
        rstudioapi::insertText(ctxt$selection[[c(1,1)]],paste0(ins_txt, "\n",obj),id = ctxt$id)
      }})
    
      observeEvent(c(input$fields,robj(),input$cut,input$action),{
        switch(input$action,
               Update={ 
                 params <- list(
                 path=robj()$path,
                 add_fields = input$fields,
                 add_default = TRUE,
                 dry.run=FALSE,
                 use_dictionary = rfile(),
                 cut = input$cut
               )
               
               output$preview<-renderText({
                 if(nchar(params$path)>0){
                   x<-do.call(moga, params) 
                   paste(x,collapse = '\n')
                 }
               })},
               Create={
                 params <- list(obj = robj()$selection[[1]]$text,
                                add_fields = input$fields,
                                add_default = TRUE,
                                print = FALSE,
                                use_dictionary = rfile(),
                                cut = input$cut
                 )
                 
                 output$preview<-renderText({
                   if(nchar(params$obj)>0){
                     do.call(makeOxygen, params)
                   }
                 })
               })
      })  
  }
  runGadget(ui, server, viewer = paneViewer(minHeight = 450))
  }