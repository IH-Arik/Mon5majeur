from unittest.mock import patch

from app.utils import email as em


def test_a_french_player_gets_a_french_reset_email():
    subject, html = em.otp_email_content("123456", "reset_password", "fr")
    assert subject == "Mon5Majeur — Réinitialise ton mot de passe"
    assert "123456" in html and "15 minutes" in html


def test_english_by_default():
    subject, _ = em.otp_email_content("123456", "verify_email", None)
    assert subject == "Mon5Majeur — Verify your email"


def test_the_brand_sender_and_the_reply_address():
    sent = {}

    class _SMTP:
        def __init__(self, *a): pass
        def __enter__(self): return self
        def __exit__(self, *a): return False
        def starttls(self): pass
        def login(self, *a): pass
        def sendmail(self, frm, to, raw): sent["raw"] = raw

    with patch.object(em.settings, "SMTP_HOST", "smtp.example"), \
            patch.object(em.settings, "EMAILS_FROM_EMAIL", "noreply@mon5majeur.fr"), \
            patch.object(em.settings, "EMAILS_FROM_NAME", "Mon5Majeur"), \
            patch.object(em.settings, "EMAILS_REPLY_TO", "support@mon5majeur.fr"), \
            patch.object(em.smtplib, "SMTP", _SMTP):
        assert em._send_email("p@x.com", "s", "<p>b</p>")
    assert "From: Mon5Majeur <noreply@mon5majeur.fr>" in sent["raw"]
    assert "Reply-To: support@mon5majeur.fr" in sent["raw"]
