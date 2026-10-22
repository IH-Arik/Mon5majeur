import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)


def _send_email(to: str, subject: str, html_body: str) -> bool:
    """Returns True on success, False on failure (never raises)."""
    if not settings.SMTP_HOST:
        logger.warning("[DEV] Email not sent (SMTP unconfigured) | to=%s | subject=%s", to, subject)
        return False

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"{settings.EMAILS_FROM_NAME} <{settings.EMAILS_FROM_EMAIL}>"
    msg["To"] = to
    if settings.EMAILS_REPLY_TO:
        msg["Reply-To"] = settings.EMAILS_REPLY_TO
    msg.attach(MIMEText(html_body, "html"))

    try:
        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
            server.starttls()
            if settings.SMTP_USER:
                server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
            server.sendmail(settings.EMAILS_FROM_EMAIL, to, msg.as_string())
        logger.info("Email sent | to=%s | subject=%s", to, subject)
        return True
    except Exception as exc:
        logger.error("Email failed | to=%s | %s", to, exc)
        return False


_TEXTS = {
    "fr": {
        "reset_password": (
            "Mon5Majeur — Réinitialise ton mot de passe",
            "Réinitialise ton mot de passe",
            "Utilise le code ci-dessous pour réinitialiser ton mot de passe Mon5Majeur.",
            "Ce code expire dans <strong>15 minutes</strong>. "
            "Si tu n'as pas demandé à réinitialiser ton mot de passe, ignore cet e-mail.",
        ),
        "verify_email": (
            "Mon5Majeur — Vérifie ton adresse e-mail",
            "Vérifie ton adresse e-mail",
            "Bienvenue sur Mon5Majeur ! Utilise le code ci-dessous pour vérifier ton adresse e-mail.",
            "Ce code expire dans <strong>15 minutes</strong>.",
        ),
    },
    "en": {
        "reset_password": (
            "Mon5Majeur — Reset your password",
            "Reset your password",
            "Use the verification code below to reset your Mon5Majeur password.",
            "This code expires in <strong>15 minutes</strong>. "
            "If you didn't request a password reset, you can ignore this email.",
        ),
        "verify_email": (
            "Mon5Majeur — Verify your email",
            "Verify your email",
            "Welcome to Mon5Majeur! Use the code below to verify your email address.",
            "This code expires in <strong>15 minutes</strong>.",
        ),
    },
}


def otp_email_content(otp: str, purpose: str, language: str | None = None) -> tuple[str, str]:
    """(subject, html) of a code e-mail in the player's language (FR or EN;
    English when unknown). Arik QA item 13: the app is French, the e-mails
    were English only."""
    texts = _TEXTS.get((language or "").lower()[:2], _TEXTS["en"])
    kind = "reset_password" if purpose == "reset_password" else "verify_email"
    subject, title, intro, footer = texts[kind]
    html = f"""
        <div style="font-family:sans-serif;max-width:480px;margin:auto">
          <h2 style="color:#E8500A">{title}</h2>
          <p>{intro}</p>
          <div style="font-size:36px;font-weight:bold;letter-spacing:8px;
                      background:#111;color:#E8500A;padding:16px 24px;
                      border-radius:8px;text-align:center;margin:24px 0">
            {otp}
          </div>
          <p style="color:#888;font-size:13px">{footer}</p>
        </div>
        """
    return subject, html


def send_otp_email(to: str, otp: str, purpose: str, language: str | None = None) -> None:
    subject, html = otp_email_content(otp, purpose, language)

    # Dev convenience only (no SMTP configured AND DEBUG on). Never in production:
    # a logged code lets anyone with log access reset the account.
    if settings.DEBUG and not settings.SMTP_HOST:
        logger.info("[OTP] to=%s purpose=%s code=%s", to, purpose, otp)
    _send_email(to, subject, html)
