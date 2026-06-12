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


def send_otp_email(to: str, otp: str, purpose: str) -> None:
    if purpose == "reset_password":
        subject = "Mon5majeur — Reset your password"
        html = f"""
        <div style="font-family:sans-serif;max-width:480px;margin:auto">
          <h2 style="color:#E8500A">Reset your password</h2>
          <p>Use the verification code below to reset your Mon5majeur password.</p>
          <div style="font-size:36px;font-weight:bold;letter-spacing:8px;
                      background:#111;color:#E8500A;padding:16px 24px;
                      border-radius:8px;text-align:center;margin:24px 0">
            {otp}
          </div>
          <p style="color:#888;font-size:13px">
            This code expires in <strong>15 minutes</strong>.
            If you didn't request a password reset, you can ignore this email.
          </p>
        </div>
        """
    else:
        subject = "Mon5majeur — Verify your email"
        html = f"""
        <div style="font-family:sans-serif;max-width:480px;margin:auto">
          <h2 style="color:#E8500A">Verify your email</h2>
          <p>Welcome to Mon5majeur! Use the code below to verify your email address.</p>
          <div style="font-size:36px;font-weight:bold;letter-spacing:8px;
                      background:#111;color:#E8500A;padding:16px 24px;
                      border-radius:8px;text-align:center;margin:24px 0">
            {otp}
          </div>
          <p style="color:#888;font-size:13px">
            This code expires in <strong>15 minutes</strong>.
          </p>
        </div>
        """

    # Log OTP in dev mode so you can test without SMTP
    logger.info("[OTP] to=%s purpose=%s code=%s", to, purpose, otp)
    _send_email(to, subject, html)
