#nhanesA - retrieve data from the CDC NHANES repository
# Christopher J. Endres 10/13/2018
#
nhanesURL <- 'https://wwwn.cdc.gov/Nchs/Nhanes/'
dataURL <- 'https://wwwn.cdc.gov/Nchs/Nhanes/search/DataPage.aspx'
dxaURL  <- "https://wwwn.cdc.gov/nchs/data/nhanes/dxa/"

demoURL <- "https://wwwn.cdc.gov/nchs/nhanes/search/variablelist.aspx?Component=Demographics"
dietURL <- "https://wwwn.cdc.gov/nchs/nhanes/search/variablelist.aspx?Component=Dietary"
examURL <- "https://wwwn.cdc.gov/nchs/nhanes/search/variablelist.aspx?Component=Examination"
labURL  <- "https://wwwn.cdc.gov/nchs/nhanes/search/variablelist.aspx?Component=Laboratory"
qURL    <- "https://wwwn.cdc.gov/nchs/nhanes/search/variablelist.aspx?Component=Questionnaire"
#ladURL  <- "https://wwwn.cdc.gov/nchs/nhanes/search/variablelist.aspx?Component=LimitedAccess"
varURLs <- c(demoURL, dietURL, examURL, labURL, qURL) #, ladURL)


# Create a list of nhanes groups
# Include convenient aliases
nhanes_group <- list()
nhanes_group['DEMO']          <- "DEMOGRAPHICS"
nhanes_group['DEMOGRAPHICS']  <- "DEMOGRAPHICS"
nhanes_group['DIETARY']       <- "DIETARY"
nhanes_group['DIET']          <- "DIETARY"
nhanes_group['EXAMINATION']   <- "EXAMINATION"
nhanes_group['EXAM']          <- "EXAMINATION"
nhanes_group['LABORATORY']    <- "LABORATORY"
nhanes_group['LAB']           <- "LABORATORY"
nhanes_group['QUESTIONNAIRE'] <- "QUESTIONNAIRE"
nhanes_group['Q']             <- "QUESTIONNAIRE"
nhanes_group['LIMITED']       <- "NON-PUBLIC"
nhanes_group['LTD']           <- "NON-PUBLIC"
nhanes_survey_groups <- unlist(unique(nhanes_group))

# Although continuous NHANES is grouped in 2-year intervals,
# for convenience we want to specify using a single year
nh_years <- list()
nh_years['1999'] <- "1999-2000"
nh_years['2000'] <- "1999-2000"
nh_years['2001'] <- "2001-2002"
nh_years['2002'] <- "2001-2002"
nh_years['2003'] <- "2003-2004"
nh_years['2004'] <- "2003-2004"
nh_years['2005'] <- "2005-2006"
nh_years['2006'] <- "2005-2006"
nh_years['2007'] <- "2007-2008"
nh_years['2008'] <- "2007-2008"
nh_years['2009'] <- "2009-2010"
nh_years['2010'] <- "2009-2010"
nh_years['2011'] <- "2011-2012"
nh_years['2012'] <- "2011-2012"
nh_years['2013'] <- "2013-2014"
nh_years['2014'] <- "2013-2014"
nh_years['2015'] <- "2015-2016"
nh_years['2016'] <- "2015-2016"
nh_years['2017'] <- "2017-2018"
nh_years['2018'] <- "2017-2018"
nh_years['2019'] <- "2019-2020"
nh_years['2020'] <- "2019-2020"
nh_years['2021'] <- "2021-2022"
nh_years['2022'] <- "2021-2022"

# Continuous NHANES table names have a letter suffix that indicates the collection interval
data_idx <- list()
data_idx["A"] <- '1999-2000'
data_idx["a"] <- '1999-2000'
data_idx["B"] <- '2001-2002'
data_idx["b"] <- '2001-2002'
data_idx["C"] <- '2003-2004'
data_idx["c"] <- '2003-2004'
data_idx["D"] <- '2005-2006'
data_idx["E"] <- '2007-2008'
data_idx["F"] <- '2009-2010'
data_idx["G"] <- '2011-2012'
data_idx["H"] <- '2013-2014'
data_idx["I"] <- '2015-2016'
data_idx["J"] <- '2017-2018'
data_idx["K"] <- '2019-2020'
data_idx["L"] <- '2021-2022'

anomalytables2005 <- c('CHLMD_DR', 'SSUECD_R', 'HSV_DR')

#------------------------------------------------------------------------------
# An internal function that determines which survey year the table belongs to.
# For most tables the year is indicated by the letter suffix following an underscore.
# E.g. for table 'BPX_E', the suffix is '_E'
# If there is no suffix, then we are likely dealing with data from 1999-2000.
.get_year_from_nh_table <- function(nh_table) {
  if(nh_table %in% anomalytables2005) {return('2005-2006')}
  nhloc <- data.frame(stringr::str_locate_all(nh_table, '_'))
  nn <- nrow(nhloc)
  if(nn!=0){ #Underscores were found
    if((nhloc$start[nn]+1) == nchar(nh_table)) {
      idx <- stringr::str_sub(nh_table, -1, -1)
      if(idx=='r'||idx=='R') {
        if(nn > 1) {
          newloc <- nhloc$start[nn-1]+1
          idx <- stringr::str_sub(nh_table, newloc, newloc)
        } else {stop('Invalid table name')}
      }
      return(data_idx[idx])
    } else { ## Underscore not 2nd to last. Assume table is from the first set.
      return("1999-2000")}
  } else #If there are no underscores then table must be from first survey
    nh_year <- "1999-2000"
}

#------------------------------------------------------------------------------
# An internal function that converts a year into the nhanes interval.
# E.g. 2003 is converted to '2003-2004'
# @param year where year is numeric in yyyy format
# @return The 2-year interval that includes the year, e.g. 2001-2002
# 
.get_nh_survey_years <- function(year) {
  if(as.character(year) %in% names(nh_years)) {
    return( as.character(nh_years[as.character(year)]) )
  }
  else {
    stop('Data for year ', year, ' are not available')
    return(NULL)
  }
}

# Internal function to determine if a number is even
.is.even <- function(x) {x %% 2 == 0}

#xpath <- '//*[@id="ContentPlaceHolder1_GridView1"]'
xpath <- '//*[@id="GridView1"]'

#------------------------------------------------------------------------------
#' Returns a list of table names for the specified survey group.
#' 
#' Enables quick display of all available tables in the survey group.
#' 
#' @importFrom stringr str_replace str_c str_match str_to_title str_sub str_split
#' @importFrom rvest xml_nodes html_table
#' @importFrom xml2 read_html
#' @importFrom magrittr %>%
#' @param data_group The type of survey (DEMOGRAPHICS, DIETARY, EXAMINATION, LABORATORY, QUESTIONNAIRE).
#' Abbreviated terms may also be used: (DEMO, DIET, EXAM, LAB, Q).
#' @param year The year in yyyy format where 1999 <= yyyy <= 2014.
#' @param nchar Truncates the table description to a max length of nchar.
#' @param details If TRUE then a more detailed description of the tables is returned (default=FALSE).
#' @param namesonly If TRUE then only the table names are returned (default=FALSE).
#' @param includerdc If TRUE then RDC only tables are included in list (default=FALSE).
#' @return The names of the tables in the specified survey group.
#' @details Data are retrieved via web scraping using html wrappers from package rvest.
#' It is often useful to display the table names in an NHANES survey. In effect this
#' is a convenient way to browse the available NHANES tables.
#' @examples
#' nhanesTables('EXAM', 2007)
#' \donttest{nhanesTables('LAB', 2009, details=TRUE, includerdc=TRUE)}
#' \donttest{nhanesTables('Q', 2005, namesonly=TRUE)}
#' @export
#'

nhanesTables <- function(data_group, year, nchar=100, details = FALSE, namesonly=FALSE, includerdc=FALSE) {
  if( !(data_group %in% names(nhanes_group)) ) {
    stop("Invalid survey group")
    return(NULL)
  }
  
  nh_year <- .get_nh_survey_years(year)
  
  turl <- str_c(nhanesURL, 'search/variablelist.aspx?Component=', 
                str_to_title(as.character(nhanes_group[data_group])), 
                '&CycleBeginYear=', unlist(str_split(as.character(nh_year), '-'))[[1]] , sep='')
  # At this point df contains every table
  df <- as.data.frame(turl %>% read_html() %>% xml_nodes(xpath=xpath) %>% html_table())
  # By default we exclude RDC Only tables as those cannot be downloaded
  
  if(!(nhanes_group[data_group]=='NON-PUBLIC')){
    if(!includerdc) {
      df <- df[(df$Use.Constraints != "RDC Only"),]
    }
  }
  
  if(details) {
    df <- unique(df[,3:length(df)])
  } else {
    df <- unique(df[,c('Data.File.Name', 'Data.File.Description')])
  }
#  df <- rename(df, c("Data.File.Name"="FileName","Data.File.Description"="Description"))
  
  #Here we exclude tables that overlap from earlier surveys
  # Get possible table suffixes for the specified year
  if(nh_year != "1999-2000") { ## No exclusion needed for first survey
    suffix <- names(data_idx[which(data_idx == nh_year)])
    suffix <- unlist(lapply(suffix, function(x) {str_c('_', x, sep='')}))
    if(nh_year == '2005-2006') {suffix <- c(suffix, anomalytables2005)}
    matches <- unique(grep(paste(suffix,collapse="|"), df[['Data.File.Name']], value=TRUE))  
    df <- df[(df$Data.File.Name %in% matches),]
  }
  if(namesonly) {
    return(as.character(df[[1]]))
  }
  df$Data.File.Description <- str_sub(df$Data.File.Description, 1, nchar)
  row.names(df) <- NULL
  return(df)  
}

#------------------------------------------------------------------------------
#' Displays a list of variables in the specified NHANES table.
#' 
#' Enables quick display of table variables and their definitions.
#' 
#' @importFrom stringr str_replace str_c str_sub str_split
#' @importFrom rvest xml_nodes html_table
#' @importFrom xml2 read_html
#' @importFrom magrittr %>%
#' @param data_group The type of survey (DEMOGRAPHICS, DIETARY, EXAMINATION, LABORATORY, QUESTIONNAIRE).
#' Abbreviated terms may also be used: (DEMO, DIET, EXAM, LAB, Q).
#' @param nh_table The name of the specific table to retrieve.
#' @param details If TRUE then all columns in the variable description are returned (default=FALSE).
#' @param nchar The number of characters in the Variable Description to print. Values are limited to 0<=nchar<=128.
#' This is used to enhance readability, cause variable descriptions can be very long.
#' @param namesonly If TRUE then only the variable names are returned (default=FALSE).
#' @return The names of the tables in the specified survey group
#' @details Data are retrieved via web scraping using html wrappers from package rvest.
#' Each data table contains multiple, sometimes more than 100, fields. It is helpful to list the field
#' descriptions to ascertain quickly if a data table is of interest.
#' @examples
#' nhanesTableVars('LAB', 'CBC_E')
#' \donttest{nhanesTableVars('EXAM', 'OHX_E', details=TRUE, nchar=50)}
#' \donttest{nhanesTableVars('DEMO', 'DEMO_F', namesonly = TRUE)}
#' @export
#' 
nhanesTableVars <- function(data_group, nh_table, details = FALSE, nchar=100, namesonly = FALSE) {
  if( !(data_group %in% names(nhanes_group)) ) {
    stop("Invalid survey group")
    return(NULL)
  }
  
  nh_year <- .get_year_from_nh_table(nh_table)
  turl <- str_c(nhanesURL, 'search/variablelist.aspx?Component=', 
                str_to_title(as.character(nhanes_group[data_group])), 
                '&CycleBeginYear=', unlist(str_split(as.character(nh_year), '-'))[[1]] , sep='')
  df <- as.data.frame(turl %>% read_html() %>% xml_nodes(xpath=xpath) %>% html_table())
  
  if(!(nh_table %in% df$Data.File.Name)) {
    stop('Table ', nh_table, ' not present in the ', data_group, ' survey' )
    return(NULL)
  }
  
  nchar_max <- 128
  if(nchar > nchar_max) {
    nchar <- nchar_max
  }
  if( details == FALSE ) { # If TRUE then only return the variable name and description
    df <- df[df$Data.File.Name == nh_table,1:2]
  } else {
    df <- df[df$Data.File.Name == nh_table,]
  }
  df[[2]] <- str_sub(df[[2]],1,nchar)
  if( namesonly == TRUE ) {
    return(as.character(unique(df[[1]])))
  }
  row.names(df) <- NULL
  return(unique(df))
}

#------------------------------------------------------------------------------
#' Download an NHANES table and return as a data frame.
#' 
#' Use to download NHANES data tables that are in SAS format.
#' 
#' @importFrom Hmisc sasxport.get
#' @importFrom stringr str_c
#' @param nh_table The name of the specific table to retrieve.
#' @return The table is returned as a data frame.
#' @details Downloads a table from the NHANES website in its entirety. NHANES tables 
#' are stored in SAS '.XPT' format. Function nhanes cannot be used to import limited 
#' access data.
#' @examples 
#' nhanes('BPX_E')
#' nhanes('FOLATE_F')
#' @export
#' 
nhanes <- function(nh_table) {
  nht <- tryCatch({    
    nh_year <- .get_year_from_nh_table(nh_table)
    url <- str_c(nhanesURL, nh_year, '/', nh_table, '.XPT', collapse='')
    
    tf <- tempfile()
    download.file(url, tf, mode = "wb", quiet = TRUE)
    return(sasxport.get(tf, lowernames=FALSE))
  },
  error = function(cond) {
    message(paste("Data set ", nh_table,  " is not available"), collapse='')
    #    message(url)
    return(NULL)
  },
  warning = function(cond) {
    message(cond, '\n')    
  }  
  )
  return(nht)
}

## #------------------------------------------------------------------------------
#' Import Dual Energy X-ray Absorptiometry (DXA) data.
#' 
#' DXA data were acquired from 1999-2006. 
#' 
#' @importFrom stringr str_c
#' @importFrom Hmisc sasxport.get
#' @importFrom utils download.file
#' @param year The year of the data to import, where 1999<=year<=2006. 
#' @param suppl If TRUE then retrieve the supplemental data (default=FALSE).
#' @param destfile The name of a destination file. If NULL then the data are imported 
#' into the R environment but no file is created.
#' @return By default the table is returned as a data frame. When downloading to file, the return argument
#' is the integer code from download.file where 0 means success and non-zero indicates failure to download.
#' @details  Provide destfile in order to write the data to file. If destfile is not provided then
#' the data will be imported into the R environment.
#' @examples
#' \donttest{dxa_b <- nhanesDXA(2001)}
#' \donttest{dxa_c_s <- nhanesDXA(2003, suppl=TRUE)}
#' \donttest{nhanesDXA(1999, destfile="dxx.xpt")}
#' @export
nhanesDXA <- function(year, suppl=FALSE, destfile=NULL) {

  dxa_fname <- function(year, suppl) {
    if(year == 1999 | year == 2000) {fname = 'dxx'}
    else if(year == 2001 | year == 2002) {fname = 'dxx_b'}
    else if(year == 2003 | year == 2004) {fname = 'dxx_c'}
    else if(year == 2005 | year == 2006) {fname = 'DXX_D'}
    if(suppl == TRUE) {
      if(year == 2005 | year == 2006) {
        fname <- str_c(fname, '_S', collapse='')
      } else {fname <- str_c(fname, '_s', collapse='')}
    }
    return(fname)
  }
  
  if(year) {
    if(!(as.character(year) %in% c('1999', '2000', '2001', '2002', '2003', '2004', '2005', '2006'))) {
      stop("Invalid survey year for DXA data")
    } else {
      fname <- dxa_fname(year, suppl)
      url <- stringr::str_c(dxaURL, fname, '.xpt', collapse='')
      if(!is.null(destfile)) {
        ok <- suppressWarnings(tryCatch({download.file(url, destfile, mode="wb", quiet=TRUE)},
                                        error=function(cond){message(cond); return(NULL)}))         
        return(ok)
      } else {
        tf <- tempfile()
        ok <- suppressWarnings(tryCatch({download.file(url, tf, mode="wb", quiet=TRUE)},
                                        error=function(cond){message(cond); return(NULL)}))
        if(!is.null(ok)) {
          return(sasxport.get(tf,lowernames=FALSE))
        } else { return(NULL) }
      }
    }
  } else { # Year not provided - no data will be returned
    stop("Year is required")
  }
}

#------------------------------------------------------------------------------
#' Returns the attributes of an NHANES data table.
#' 
#' Returns attributes such as number of rows, columns, and memory size,
#' but does not return the table itself.
#' 
#' @importFrom Hmisc sasxport.get
#' @importFrom stringr str_c
#' @importFrom utils object.size
#' @param nh_table The name of the specific table to retrieve
#' @return The following attributes are returned as a list \cr
#' nrow = number of rows \cr
#' ncol = number of columns \cr
#' names = name of each column \cr
#' unique = true if all SEQN values are unique \cr
#' na = number of 'NA' cells in the table \cr
#' size = total size of table in bytes \cr
#' types = data types of each column
#' @details nhanesAttr allows one to check the size and other charactersistics of a data table 
#' before importing into R. To retrieve these characteristics, the specified table is downloaded,
#' characteristics are determined, then the table is deleted.
#' @examples 
#' nhanesAttr('BPX_E')
#' nhanesAttr('FOLATE_F')
#' @export
#' 
nhanesAttr <- function(nh_table) {
  nht <- tryCatch({    
    nh_year <- .get_year_from_nh_table(nh_table)
    url <- str_c(nhanesURL, nh_year, '/', nh_table, '.XPT', collapse='')
    tmp <- sasxport.get(url,lowernames=FALSE)
    nhtatt <- attributes(tmp)
    nhtatt$row.names <- NULL
    nhtatt$nrow <- nrow(tmp)
    nhtatt$ncol <- ncol(tmp)
    nhtatt$unique <- (length(unique(tmp$SEQN)) == nhtatt$nrow)
    nhtatt$na <- sum(is.na(tmp))
    nhtatt$size <- object.size(tmp)
    nhtatt$types <- sapply(tmp,class)
    rm(tmp)
    return(nhtatt)
  },
  error = function(cond) {
    message(paste("Data from ", nh_table, " are not available"))
    return(NA)
  },
  warning = function(cond) {
    message(cond, '\n')    
  }  
  )
  return(nht)  
}

#------------------------------------------------------------------------------
#' Perform a search over the comprehensive NHANES variable list.
#' 
#' The descriptions in the master variable list will be filtered by the
#' provided search terms to retrieve a list of relevant variables. 
#' The search can be restricted to specific survey years by specifying ystart and/or ystop.
#' 
#' @importFrom rvest html_table
#' @importFrom xml2 xml_children xml_text read_html
#' @importFrom magrittr %>%
#' @param search_terms List of terms or keywords.
#' @param exclude_terms List of exclusive terms or keywords.
#' @param data_group Which data groups (e.g. DIET, EXAM, LAB) to search. Default is to search all groups.
#' @param ignore.case Ignore case if TRUE. (Default=FALSE).
#' @param ystart Four digit year of first survey included in search, where ystart >= 1999.
#' @param ystop  Four digit year of final survey included in search, where ystop >= ystart.
#' @param includerdc If TRUE then RDC only tables are included in list (default=FALSE).
#' @param nchar Truncates the variable description to a max length of nchar.
#' @param namesonly If TRUE then only the table names are returned (default=FALSE).
#' @return A list of tables that match the search terms. 
#' @details nhanesSearch is useful to obtain a comprehensive list of relevant tables.
#' Search terms will be matched against the variable descriptions in the NHANES Comprehensive
#' Variable Lists.
#' Matching variables must have at least one of the search_terms and not have any exclude_terms.
#' The search may be restricted to specific surveys using ystart and ystop.
#' If no arguments are given, then nhanesSearch returns the complete variable list.
#' @examples
#'  \donttest{nhanesSearch("bladder", ystart=2001, ystop=2008, nchar=50)}
#'  \donttest{nhanesSearch("urin", exclude_terms="During", ystart=2009)}
#'  \donttest{nhanesSearch(c("urine", "urinary"), ignore.case=TRUE, ystop=2006, namesonly=TRUE)}
#' @export
#' 
nhanesSearch <- function(search_terms=NULL, exclude_terms=NULL, data_group=NULL, ignore.case=FALSE, 
                         ystart=NULL, ystop=NULL, includerdc=FALSE, nchar=100, namesonly=FALSE) {
  
  if(is.null(search_terms)) {
    stop("Search term is missing")
  }

# Need to loop over url's

  df_initialized = FALSE
  for(i in 1:length(varURLs)) {  
    vlhtml <- read_html(varURLs[i])
    
    xpathh <- '//*[@id="GridView1"]/thead/tr'
    hnodes <- xml_nodes(vlhtml, xpath=xpathh)
    vmcols <- sapply(xml_children(hnodes),xml_text)
    vmcols <- unlist(lapply(str_split(vmcols, " "), paste0, collapse='.'))
    
    xpathv <- '//*[@id="GridView1"]/tbody/tr'
    vnodes <- xml_nodes(vlhtml, xpath=xpathv)
    if(length(vnodes) > 0){
      if(!df_initialized) {
        df <- t(sapply(lapply(vnodes,xml_children),xml_text)) %>% as.data.frame(stringsAsFactors=FALSE)
        df_initialized = TRUE
      } else {
        dfadd <- t(sapply(lapply(vnodes,xml_children),xml_text)) %>% as.data.frame(stringsAsFactors=FALSE)
        df <- rbind(df, dfadd)
      }
    }
  }
  
  if(is.null(df)) {
    stop("No data was found. Perhaps the NHANES url has changed")
    return(NULL)
  }
  names(df) <- vmcols
  
  # Remove rdc tables if desired
  if(includerdc == FALSE){
    df <- df[(df$Use.Constraints != "RDC Only"),]
  }

  # 
  if(!is.null(search_terms)) {
    idx <- grep(paste(search_terms,collapse="|"), df[['Variable.Description']], ignore.case=ignore.case, value=FALSE)
    if(length(idx) > 0) {df <- df[idx,]} else {
      message("No matches found")
      return(NULL)
    }
  }
  
  if(!is.null(data_group)){ # Restrict search to specific data group(s) e.g. 'EXAM' or 'LAB'
    sgroups <- list()
    for(i in 1:length(data_group)) {
      if(data_group[i] %in% names(nhanes_group)) {
        sgroups <- c(sgroups, nhanes_group[[data_group[i]]])
      }
    }
    if(length(sgroups)>0) {
      df <- df[grep(paste(unlist(sgroups),collapse="|"), df$Component, ignore.case=TRUE),]
    }
  }
  
  if(!is.null(ystop)){  # ystop has been provided
    if(is.numeric(ystop)) {
      if(ystop < 1999) {stop("Invalid stop year")}
    } else {
      stop(paste( c(ystop, "is not a valid stop year"), collapse=' '))
    }
    if(!is.null(ystart)) { # ystart has also been provided
      if(!is.numeric(ystart)) {stop("Start year (ystart) must be a 4-digit year")}
      if( ystart > ystop ) {
        stop('Stop year (ystop) cannot precede the Start year (ystart)')
      } else { #Determine if Start year is odd or even
        if(.is.even(ystart)) {
          df <- df[(as.numeric(df$EndYear) >= ystart),]
        } else {
          df <- df[(as.numeric(df$Begin.Year) >= ystart),]
        }
        if(.is.even(ystop)) {
          df <- df[(as.numeric(df$EndYear) <= ystop),]
        } else {
          df <- df[(as.numeric(df$Begin.Year) <= ystop),]
        }
      }
    } else { # No ystart, assume it is 1999 (i.e. the first survey)
      if(.is.even(ystop)) {
        df <- df[(as.numeric(df$EndYear) <= ystop),]
      } else {
        df <- df[(as.numeric(df$Begin.Year) <= ystop),]
      }
    }
  } else if(!is.null(ystart)) { # ystart only, i.e. no ystop
    if(!is.numeric(ystart)) {stop("Start year (ystart) must be a 4-digit year")}
    if(.is.even(ystart)) {
      df <- df[(as.numeric(df$EndYear) >= ystart),]
    } else {
      df <- df[(as.numeric(df$Begin.Year) >= ystart),]
    }
  }
  
  if(!is.null(exclude_terms)) {
    idx <- grep(paste(exclude_terms,collapse="|"), df[['Variable.Description']], ignore.case=ignore.case, value=FALSE)
    if(length(idx)>0) {df <- df[-idx,]}
  }
  row.names(df) <- NULL
  if(namesonly) {
    return(unique(df$Data.File.Name))
  }
  df$Variable.Description <- str_sub(df$Variable.Description, 1, nchar)
  return(df)
}
#------------------------------------------------------------------------------
#' Search for matching table names
#' 
#' Returns a list of table names that match a specified pattern.
#' 
#' @importFrom rvest html_table
#' @importFrom xml2 read_html
#' @importFrom magrittr %>%
#' @param pattern Pattern of table names to match  
#' @param ystart Four digit year of first survey included in search, where ystart >= 1999.
#' @param ystop  Four digit year of final survey included in search, where ystop >= ystart.
#' @param includerdc If TRUE then RDC only tables are included (default=FALSE).
#' @param nchar Truncates the variable description to a max length of nchar.
#' @param details If TRUE then complete table information from the comprehensive
#' data list is returned (default=FALSE).
#' @return A list of table names that match the pattern.
#' @details Searches the Doc File field in the NHANES Comprehensive Data List 
#' (see https://wwwn.cdc.gov/nchs/nhanes/search/DataPage.aspx) for tables
#' that match a given name pattern. Only a single pattern may be entered.
#' @examples
#' \donttest{nhanesSearchTableNames('BMX')}
#' nhanesSearchTableNames('HPVS', includerdc=TRUE, details=TRUE)
#' @export
#' 
nhanesSearchTableNames <- function(pattern=NULL, ystart=NULL, ystop=NULL, includerdc=FALSE, nchar=100, details=FALSE) {
  if(is.null(pattern)) {stop('No pattern was entered')}
  if(length(pattern)>1) {
    pattern <- pattern[1]
    warning("Multiple patterns entered. Only the first will be matched.")
  }
  
  df <- data.frame(read_html(dataURL) %>% xml_nodes(xpath=xpath) %>% html_table())
  df <- df[grep(paste(pattern,collapse="|"), df$Doc.File),]
  if(nrow(df)==0) {return(NULL)}
  if(!includerdc) {
    df <- df[!(df$Data.File=='RDC Only'),]
  }
  
  if( !is.null(ystart) || !is.null(ystop) ) {
    # Use the first year of cycle (the odd year) for comparison
    year1 <- as.integer(matrix(unlist(strsplit(df$Years, '-')), ncol=2, byrow=TRUE)[,1])
    
    if(!is.null(ystop)){  # ystop has been provided
      if(is.numeric(ystop)) {
        if(ystop < 1999) {stop("Invalid stop year")}
      } else {
        stop(paste( c(ystop, "is not a valid stop year"), collapse=' '))
      }
      if(!is.null(ystart)) { # ystart has also been provided
        if(!is.numeric(ystart)) {stop("Start year (ystart) must be a 4-digit year")}
        if( ystart > ystop ) {
          stop('Stop year (ystop) cannot precede the Start year (ystart)')
        } else { #Determine if Start year is odd or even. If even then convert to odd year.
          if(.is.even(ystart)) {
            ystart <- ystart - 1
          }
          df <- df[(year1 >= ystart & year1 <= ystop),]
        }
      } else { # No ystart, assume it is 1999 (i.e. the first survey)
        df <- df[(year1 <= ystop),]
      }
    } else if(!is.null(ystart)) { # ystart only, i.e. no ystop
      if(!is.numeric(ystart)) {stop("Start year (ystart) must be a 4-digit year")}
      if(.is.even(ystart)) {
        ystart <- ystart - 1
      } 
      df <- df[(year1 >= ystart),]
    }
  }
  
  if(nrow(df)==0) {return(NULL)}
  row.names(df) <- NULL
  if(details==TRUE){
    df$Data.File.Name <- str_sub(df$Data.File.Name, 1, nchar)
    return(df)
  } else {
    return(unlist(strsplit(df$Doc.File, " Doc")))
  }
}
#------------------------------------------------------------------------------
#' Search for tables that contain a specified variable.
#' 
#' Returns a list of table names that contain the variable
#' @importFrom rvest xml_nodes html_table
#' @importFrom xml2 xml_children xml_text read_html
#' @importFrom magrittr %>%
#' @param varname Name of variable to match.
#' @param ystart Four digit year of first survey included in search, where ystart >= 1999.
#' @param ystop  Four digit year of final survey included in search, where ystop >= ystart.
#' @param includerdc If TRUE then RDC only tables are included in list (default=FALSE).
#' @param nchar Truncates the variable description to a max length of nchar.
#' @param namesonly If TRUE then only the table names are returned (default=TRUE).
#' @details The NHANES Comprehensive Variable List is scanned to find all data tables that
#' contain the given variable name. Only a single variable name may be entered, and only
#' exact matches will be found.
#' @examples 
#' \donttest{nhanesSearchVarName('BMXLEG')}
#' \donttest{nhanesSearchVarName('BMXHEAD', ystart=2003)}
#' @export
#'  
nhanesSearchVarName <- function(varname=NULL, ystart=NULL, ystop=NULL, includerdc=FALSE, nchar=100, namesonly=TRUE) {
  if(is.null(varname)) {stop('No varname was entered')}
  if(length(varname)>1) {
    varname <- varname[1]
    warning("Multiple variable names entered. Only the first will be matched.")
  }
  
  #  xpt <- str_c('//*[@id="ContentPlaceHolder1_GridView1"]/*[td[1]="', varname, '"]', sep='')
  xpt <- str_c('//*[@id="GridView1"]/tbody/*[td[1]="', varname, '"]', sep='')
  df_initialized = FALSE
  
  for(i in 1:length(varURLs)) {
    tabletree <- varURLs[i] %>% read_html() %>% xml_nodes(xpath=xpt)
    ttlist <- lapply(lapply(tabletree, xml_children), xml_text)
    # Convert the list to a data frame
    
    if(length(ttlist) > 0) { # Determine if there was a successful match
      if(!df_initialized) {
        df <- unique(data.frame(matrix(unlist(ttlist), nrow=length(ttlist), byrow=TRUE), stringsAsFactors = FALSE))
        df_initialized = TRUE
      } else { # End up here if df is already initialized
        dfadd <- unique(data.frame(matrix(unlist(ttlist), nrow=length(ttlist), byrow=TRUE), stringsAsFactors = FALSE))
        if(nrow(dfadd) > 0) {
          df <- rbind(df,dfadd)
        }
      }
    }
  }
  
  if(!df_initialized) { # There was no successful match
    return(NULL)
  }
  
  names(df) <- c('Variable.Name', 'Variable.Description', 'Data.File.Name', 'Data.File.Description', 
                 'Begin.Year', 'EndYear', 'Component', 'Use.Constraints')
  
  if(includerdc == FALSE){
    df <- df[(df$Use.Constraints != "RDC Only"),]
  }
  
  if(!is.null(ystop)){  # ystop has been provided
    if(is.numeric(ystop)) {
      if(ystop < 1999) {stop("Invalid stop year")}
    } else {
      stop(paste( c(ystop, "is not a valid stop year"), collapse=' '))
    }
    if(!is.null(ystart)) { # ystart has also been provided
      if(!is.numeric(ystart)) {stop("Start year (ystart) must be a 4-digit year")}
      if( ystart > ystop ) {
        stop('Stop year (ystop) cannot precede the Start year (ystart)')
      } else { #Determine if Start year is odd or even
        if(.is.even(ystart)) {
          df <- df[(df$EndYear >= ystart),]
        } else {
          df <- df[(df$Begin.Year >= ystart),]
        }
        if(.is.even(ystop)) {
          df <- df[(df$EndYear <= ystop),]
        } else {
          df <- df[(df$Begin.Year <= ystop),]
        }
      }
    } else { # No ystart, assume it is 1999 (i.e. the first survey)
      if(.is.even(ystop)) {
        df <- df[(df$EndYear <= ystop),]
      } else {
        df <- df[(df$Begin.Year <= ystop),]
      }
    }
  } else if(!is.null(ystart)) { # ystart only, i.e. no ystop
    if(!is.numeric(ystart)) {stop("Start year (ystart) must be a 4-digit year")}
    if(.is.even(ystart)) {
      df <- df[(df$EndYear >= ystart),]
    } else {
      df <- df[(df$Begin.Year >= ystart),]
    }
  }
  
  row.names(df) <- NULL
  if(nrow(df)==0) { return(NULL) }
  if(namesonly) {
    return( unique(df$Data.File.Name) )
  }
  df$Variable.Description <- str_sub(df$Variable.Description, 1, nchar)
  return(df)
}

#------------------------------------------------------------------------------
#' Display code translation information.
#' 
#' Returns code translations for categorical variables, 
#' which appear in most NHANES tables.
#' 
#' @importFrom stringr str_c str_locate str_sub 
#' @importFrom rvest xml_nodes html_table
#' @importFrom xml2 read_html
#' @importFrom plyr mapvalues
#' @param nh_table The name of the NHANES table to retrieve.
#' @param colnames The names of the columns to translate.
#' @param data If a data frame is passed, then code translation will be applied directly to the data frame. \cr
#' In that case the return argument is the code-translated data frame.
#' @param nchar Applies only when data is defined. Code translations can be very long. \cr
#' Truncate the length by setting nchar (default = 32).
#' @param mincategories The minimum number of categories needed for code translations to be applied to the data (default=2).
#' @param details If TRUE then all available table translation information is displayed (default=FALSE).
#' @param dxa If TRUE then the 2005-2006 DXA translation table will be used (default=FALSE).
#' @return The code translation table (or translated data frame when data is defined).
#' @details Code translation tables are retrieved via webscraping using rvest. 
#' Many of the NHANES data tables have encoded values. E.g. 1 = 'Male', 2 = 'Female'.
#' Thus it is often helpful to view the code translations and perhaps insert the translated values
#' in a data frame. Note that Hmisc supports "labelled" fields. When a translation is applied directly
#' to a column in a data frame, the column class is first converted to 'factor' and then the coded
#' values are replaced with the code translations.
#' @examples
#' nhanesTranslate('DEMO_B', c('DMDBORN','DMDCITZN'))
#' nhanesTranslate('BPX_F', 'BPACSZ', details=TRUE)
#' \donttest{nhanesTranslate('BPX_F', 'BPACSZ', data=nhanes('BPX_F'))}
#' @export
#' 
nhanesTranslate <- function(nh_table, colnames=NULL, data = NULL, nchar = 32, 
                            mincategories = 2, details=FALSE, dxa=FALSE) {
  if(is.null(colnames)) {
    message('Column name is required')
    return(0)
  }
  
  get_translation_table <- function(colname, url, details) {
    xpt <- str_c('//*[h3[a[@name="', colname, '"]]]', sep='')
    tabletree <- url %>% read_html() %>% xml_nodes(xpath=xpt)
    if(length(tabletree)==0) { # If not found then try 'id' instead of 'name'
      xpt <- str_c('//*[h3[@id="', colname, '"]]', sep='')
      tabletree <- url %>% read_html() %>% xml_nodes(xpath=xpt)
    }
    if(length(tabletree)>0) {
      tabletrans <- as.data.frame(xml_nodes(tabletree, 'table') %>% html_table())
    } else { # Code table not found so let's see if last letter should be lowercase
      nc <- nchar(colname)
      if(length(grep("[[:upper:]]", stringr::str_sub(colname, start=nc, end=nc)))>0){
        lcnm <- colname
        stringr::str_sub(lcnm, start=nc, end=nc) <- tolower(stringr::str_sub(lcnm, start=nc, end=nc))
        xpt <- str_c('//*[h3[a[@name="', lcnm, '"]]]', sep='')
        tabletree <- url %>% read_html() %>% xml_nodes(xpath=xpt)
        if(length(tabletree)==0) { # If not found then try 'id' instead of 'name'
          xpt <- str_c('//*[h3[@id="', lcnm, '"]]', sep='')
          tabletree <- url %>% read_html() %>% xml_nodes(xpath=xpt)
        }
        
        if(length(tabletree)>0) {
          tabletrans <- as.data.frame(xml_nodes(tabletree, 'table') %>% html_table())
        } else { # Still not found even after converting to lowercase
          warning(c('Column "', colname, '" not found'), collapse='')
          return(NULL)
        }
      } else { #Last character is not an uppercase letter, thus can't convert to lowercase
        warning(c('Column "', colname, '" not found'), collapse='')
        return(NULL)
      }
    }
    
    if(length(tabletrans) > 0) {
      if(details == FALSE) {
        tabletrans <- tabletrans[,c('Code.or.Value', 'Value.Description')]
      }
      return(tabletrans)
    } else { 
      warning(c('No translation table is available for ', colname), collapse='')
      return(NULL)
    }
  }
  
  if(dxa) {
    code_translation_url <- "https://wwwn.cdc.gov/Nchs/Nhanes/2005-2006/DXX_D.htm"
  } else {
    nh_year <- .get_year_from_nh_table(nh_table)
    if(is.null(nh_year)) {
      return(NULL)
    }  
    code_translation_url <- str_c(nhanesURL, nh_year, '/', nh_table, '.htm', sep='')
  }
  translations <- lapply(colnames, get_translation_table, code_translation_url, details)
  names(translations) <- colnames
  
  nchar_max <- 128
  if(nchar > nchar_max) {
    nchar <- nchar_max
  }
  
  if(is.null(data)) { ## If no data to translate then just return the translation table
    return(Filter(Negate(function(x) is.null(unlist(x))), translations))
  } else {
    #    message("Need to decide what to do when data are passed in")
    translations <- Filter(Negate(function(x) is.null(unlist(x))), translations)
    colnames     <- as.list(names(translations))
    
    translated <- c() ## Let's keep track of columns that were translated
    notfound   <- c() ## Keep track of columns that were not found
    nskip <- grep('Range', translations) ## 'Range' of values indicates the column is not coded
    for( i in 1:length(colnames) ) {
      if(!(i %in% nskip)) {
        cname <- unlist(colnames[i])
        sstr <- str_c('^', cname, '$') # Construct the search string
        idx <- grep(sstr, names(data)) 
        if(length(idx)>0) { ## The column is present. Next we need to decide if it should be translated.
          if(length(levels(as.factor(data[[idx]]))) >= mincategories) {
            data[[idx]] <- as.factor(data[[idx]])
            data[[idx]] <- suppressMessages(plyr::mapvalues(data[[idx]], from = translations[[cname]][['Code.or.Value']], 
                                                            to = str_sub(translations[[cname]][['Value.Description']], 1, nchar)))
            translated <- c(translated, cname) }
        } else {
          notfound <- c(notfound, cname)
        }
      }
    }
    
    if(length(translated) > 0) {
      message(paste(c("Translated columns:", translated), collapse = ' '))
      if(length(notfound) > 0)
        message(paste(c("Columns not found:", notfound), collapse = ' '))
    } else {
      warning("No columns were translated")
    }
    return(data)
  }
}

#------------------------------------------------------------------------------
#' Open a browser to NHANES.
#' 
#' The browser may be directed to a specific year, survey, or table.
#' 
#' @importFrom stringr str_c str_to_title str_split str_sub str_extract_all
#' @importFrom utils browseURL
#' @param year The year in yyyy format where 1999 <= yyyy <= 2016.
#' @param data_group The type of survey (DEMOGRAPHICS, DIETARY, EXAMINATION, LABORATORY, QUESTIONNAIRE).
#' Abbreviated terms may also be used: (DEMO, DIET, EXAM, LAB, Q).
#' @param nh_table The name of an NHANES table.
#' @details browseNHANES will open a web browser to the specified NHANES site.
#' @examples
#' browseNHANES()                     # Defaults to the main data sets page
#' browseNHANES(2005)                 # The main page for the specified survey year
#' browseNHANES(2009, 'EXAM')         # Page for the specified year and survey group
#' browseNHANES(nh_table = 'VIX_D')   # Page for a specific table
#' browseNHANES(nh_table = 'DXA')     # DXA main page
#' @export
#' 

browseNHANES <- function(year=NULL, data_group=NULL, nh_table=NULL) {
  if(!is.null(nh_table)){ # Specific table name was given
    if('DXA'==toupper(nh_table)) { # Special case for DXA
      browseURL("https://wwwn.cdc.gov/nchs/nhanes/dxa/dxa.aspx")
    } else {
      nh_year <- .get_year_from_nh_table(nh_table)
      url <- str_c(nhanesURL, nh_year, '/', nh_table, '.htm', sep='')
      browseURL(url)
    }
  } else if(!is.null(year)) {
    if(!is.null(data_group)) {
      nh_year <- .get_nh_survey_years(year)
      url <- str_c(nhanesURL, 'Search/DataPage.aspx?Component=', 
                   str_to_title(as.character(nhanes_group[data_group])), 
                   '&CycleBeginYear=', unlist(str_split(as.character(nh_year), '-'))[[1]] , sep='')
      browseURL(url)
    } else { # Go to the two year survey page 
      nh_year <- .get_nh_survey_years(year)
#      nh_year <- str_c(str_sub(unlist(str_extract_all(nh_year,"[[:digit:]]{4}")),3,4),collapse='_')
      nh_year <- unlist(str_extract_all(nh_year,"[[:digit:]]{4}"))[1]
      url <- str_c(nhanesURL, 'continuousnhanes/default.aspx?BeginYear=', nh_year, sep='')
      browseURL(url)
    }
  } else {
    browseURL("https://wwwn.cdc.gov/nchs/nhanes/Default.aspx")
  }
}
#------------------------------------------------------------------------------
