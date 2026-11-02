#===============================================================================
# PharmaBI
# Script: R/reporting/knit_and_email.R
# Objective: Generate HTML and PDF, then email them from the RStudio Knit button
#===============================================================================

knit_and_email <- function(input, ...) {
  input_file <- normalizePath(input, winslash = "/", mustWork = TRUE)
  report_dir <- dirname(input_file)
  project_root <- dirname(report_dir)

  if (!requireNamespace("rmarkdown", quietly = TRUE)) {
    stop("Install rmarkdown before knitting the report.", call. = FALSE)
  }

  # render() does not call the YAML Knit handler again.
  html_file <- rmarkdown::render(
    input = input_file,
    output_format = "html_document",
    output_dir = report_dir,
    knit_root_dir = project_root,
    envir = new.env(parent = globalenv()),
    encoding = "UTF-8"
  )
  html_file <- normalizePath(html_file, winslash = "/", mustWork = TRUE)

  config_file <- file.path(project_root, "config", "report_email.R")
  if (!file.exists(config_file)) {
    warning(
      "HTML generated. PDF/email skipped: configure config/report_email.R on this PC.",
      call. = FALSE
    )
    return(html_file)
  }

  config_env <- new.env(parent = baseenv())
  sys.source(config_file, envir = config_env)
  if (!exists("mail_config", envir = config_env, inherits = FALSE)) {
    stop("config/report_email.R must define mail_config. HTML is already saved.",
         call. = FALSE)
  }
  config <- config_env$mail_config

  if (!requireNamespace("pagedown", quietly = TRUE)) {
    stop("HTML generated. Install pagedown to generate the PDF.", call. = FALSE)
  }

  pdf_file <- sub("\\.html$", ".pdf", html_file, ignore.case = TRUE)
  pdf_temp <- tempfile("pharmabi_pdf_", tmpdir = report_dir, fileext = ".pdf")
  on.exit(unlink(pdf_temp), add = TRUE)

  tryCatch(
    pagedown::chrome_print(
      input = html_file,
      output = pdf_temp,
      browser = pagedown::find_chrome(),
      format = "pdf",
      async = FALSE,
      timeout = 120,
      options = list(
        landscape = TRUE,
        paperWidth = 8.27,
        paperHeight = 11.69,
        marginTop = 0.3,
        marginBottom = 0.3,
        marginLeft = 0.3,
        marginRight = 0.3,
        printBackground = TRUE,
        preferCSSPageSize = FALSE,
        scale = 0.8
      )
    ),
    error = function(e) {
      stop(
        "HTML saved, but PDF generation failed. No email sent. ",
        conditionMessage(e), call. = FALSE
      )
    }
  )

  if (!file.exists(pdf_temp) || is.na(file.info(pdf_temp)$size) ||
      file.info(pdf_temp)$size == 0) {
    stop("HTML saved, but a new PDF was not produced. No email sent.", call. = FALSE)
  }
  if (!file.copy(pdf_temp, pdf_file, overwrite = TRUE)) {
    stop("Cannot save the PDF; check whether it is open elsewhere. No email sent.",
         call. = FALSE)
  }
  message("HTML and PDF generated: ", basename(html_file), ", ", basename(pdf_file))

  if (!isTRUE(config$enabled)) {
    message("Email disabled in local configuration. Files are available locally.")
    return(html_file)
  }

  # Only new, successfully generated files reach the email step.
  sent <- tryCatch({
    for (pkg in c("blastula", "keyring")) {
      if (!requireNamespace(pkg, quietly = TRUE)) {
        stop("Install ", pkg, " to enable email delivery.", call. = FALSE)
      }
    }
    for (field in c("from", "to", "credential_id")) {
      value <- config[[field]]
      if (!is.character(value) || length(value) != 1L ||
          is.na(value) || !nzchar(trimws(value))) {
        stop("Configure mail_config$", field, " in config/report_email.R.",
             call. = FALSE)
      }
    }

    email <- blastula::compose_email(
      body = blastula::md(paste0(
        "The PharmaBI retail sales report was generated on **",
        format(Sys.time(), "%Y-%m-%d %H:%M %Z"),
        "**. The HTML and PDF versions are attached."
      ))
    )
    email <- blastula::add_attachment(email, file = html_file)
    email <- blastula::add_attachment(email, file = pdf_file)

    blastula::smtp_send(
      email = email,
      from = config$from,
      to = config$to,
      subject = paste("PharmaBI report -", format(Sys.time(), "%Y-%m-%d %H:%M")),
      credentials = blastula::creds_key(config$credential_id),
      verbose = FALSE
    )
    TRUE
  }, error = function(e) {
    warning(
      "HTML/PDF saved, but email delivery failed: ", conditionMessage(e),
      call. = FALSE
    )
    FALSE
  })

  if (sent) {
    message("PharmaBI: email accepted by the SMTP server for ", config$to, ".")
  } else {
    message("PharmaBI: email delivery was not confirmed; the local files remain available.")
  }

  # RStudio can open the rendered HTML after the custom Knit handler completes.
  html_file
}
