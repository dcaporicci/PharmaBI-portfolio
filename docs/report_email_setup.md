# Automatic report delivery from the Knit button

The custom Knit handler renders the retail report to HTML, prints that HTML to
PDF with Chrome/Edge/Chromium, then sends both files through SMTP. The SMTP
provider is defined by a local credential key rather than the report source.

## Install on each PC

Keep the included files at their project-relative paths:

- `reports/01_sales_report.Rmd`
- `R/reporting/knit_and_email.R`

In the RStudio Console:

```r
install.packages(c("pagedown", "blastula", "keyring"))
```

Chrome, Edge or Chromium must also be installed. The report assumes the existing
PharmaBI packages, fact data and local ATC reference are available.

Add these rules to `.gitignore` before creating the local configuration:

```gitignore
config/report_email.R
reports/*.html
reports/*.pdf
```

Create the local file `config/report_email.R` with the following contents,
replacing both example addresses with your actual Infomaniak address:

```r
mail_config <- list(
  enabled = TRUE,
  from = "your-address@ik.me",
  to = "your-address@ik.me",
  credential_id = "pharmabi"
)
```

Keep `credential_id = "pharmabi"`. To check HTML and PDF generation without
sending, temporarily set `enabled = FALSE`, then restore it to `TRUE` to enable
automatic email delivery. This local file is ignored by Git and contains no
password. Configure it separately on each PC.

## Infomaniak credential setup

Create a device password for your sending mailbox in Infomaniak, naming the
new device PharmaBI. The exact interface depends on whether the address belongs
to my kSuite (for example, an ik.me address) or a Mail Service with a custom domain.
Use the password generated for this mailbox/device, rather than the password
used to sign into the Infomaniak Manager.

Verified SMTP settings (Infomaniak documentation checked on 2026-10-12):

| Setting | Value |
| --- | --- |
| Host | `mail.infomaniak.com` |
| Port | `587` |
| Encryption | STARTTLS |
| Username | Full sending email address |
| Password | Device password generated for the mailbox |

Run this once in the RStudio Console, replacing the address with your actual
Infomaniak address (the domain need not be ik.me):

```r
blastula::create_smtp_creds_key(
  id = "pharmabi",
  user = "your-address@ik.me",
  host = "mail.infomaniak.com",
  port = 587,
  use_ssl = TRUE,
  overwrite = TRUE
)
```

`overwrite = TRUE` replaces any existing SMTP configuration stored under the
same key ID on this PC. Enter the device password only in the local password
prompt shown by the function. The credential is stored through the operating
system's keyring. Do not paste it into the script, the configuration, a Git
commit, or a conversation. Configure the key separately on Windows and Linux;
Git does not transfer it.

The mailbox device password is used for SMTP independently of two-factor
verification on the Infomaniak account. If account 2FA is enabled, it may be
required when you sign into the administration interface to configure the
password; no interactive 2FA confirmation is required for each report send.

## Custom Knit YAML

The custom handler uses `knit: |-` to preserve the function body while stripping
the final newline. Keep the minus sign: a trailing newline can separate the
function expression from the call assembled by RStudio. Edit this header in
Source mode.

## Using Knit

Open `PharmaBI.Rproj` and `reports/01_sales_report.Rmd`, then click Knit.

With local configuration present, Knit creates HTML and an A4 landscape PDF.
With `enabled = TRUE`, it attempts one email with both generated attachments.
Each subsequent successful Knit repeats the send. Inspect the Console message:
SMTP server acceptance is not a guarantee of inbox delivery; check the receiving inbox on the first run.

An analysis/render failure prevents email delivery. A PDF failure preserves the
HTML and prevents sending. An email error preserves both generated files and
prints an explicit warning. Temporary PDF generation prevents an old PDF from
being attached if the new conversion fails.

If local configuration is missing on another PC, Knit still generates the HTML
and warns that PDF/email were skipped. With `enabled = FALSE`, it generates both
files but skips email. A direct `rmarkdown::render()` call bypasses the custom
Knit handler and renders the HTML without emailing.

## Switching providers later

Update the local sending address and replace the SMTP key with one configured
for the new provider's verified host, port and TLS settings. Use the same key ID
and `overwrite = TRUE`. The report and Knit handler need no provider-specific
changes. Obtain the SMTP settings from the provider's current documentation.

## Verification status

On 2026-10-12, the user confirmed successful end-to-end execution on Windows 11:
the custom Knit workflow generated the report files and sent them through
Infomaniak. An initial syntax error in the custom Knit invocation was resolved by
changing the YAML block indicator from `knit: |` to `knit: |-`.

Linux execution and its local credential setup remain to be verified. PDF layout
can be reviewed in the generated file, particularly for wide tables.

## References

- https://bookdown.org/yihui/rmarkdown-cookbook/custom-knit.html
- https://search.r-project.org/CRAN/refmans/pagedown/html/chrome_print.html
- https://rstudio.github.io/blastula/reference/create_smtp_creds_key.html
- https://rstudio.github.io/blastula/reference/smtp_send.html
- https://www.infomaniak.com/it/assistenza/faq/468/comprendere-le-porte-e-i-protocolli-di-posta-elettronica
- https://www.infomaniak.com/it/assistenza/faq/1321/aggiungi-un-dispositivo-crea-una-password-per-la-posta-dal-servizio-di-posta
- https://www.infomaniak.com/it/assistenza/faq/1940/attiva-lautenticazione-a-due-fattori-2fa-per-gli-accessi-allaccount-infomaniak
