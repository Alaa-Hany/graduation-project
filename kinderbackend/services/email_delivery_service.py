import logging
import os
import smtplib
from email.message import EmailMessage

import httpx

logger = logging.getLogger(__name__)

BREVO_API_URL = "https://api.brevo.com/v3/smtp/email"


class EmailDeliveryService:
    def __init__(self) -> None:
        # When BREVO_API_KEY is set we deliver over HTTPS (port 443), which works
        # on hosts that block outbound SMTP (e.g. Render's free tier). Otherwise we
        # fall back to SMTP, which is convenient for local development.
        self.brevo_api_key = os.getenv("BREVO_API_KEY", "").strip()

        self.host = os.getenv("SMTP_HOST", "smtp.gmail.com")
        self.port = int(os.getenv("SMTP_PORT", "465"))
        self.username = os.getenv("SMTP_USERNAME", "")
        self.password = os.getenv("SMTP_PASSWORD", "")
        self.from_email = os.getenv("SMTP_FROM_EMAIL") or self.username
        self.from_name = os.getenv("SMTP_FROM_NAME", "Kinder World")
        self.use_ssl = os.getenv("SMTP_USE_SSL", "true").lower() == "true"
        self.use_tls = os.getenv("SMTP_USE_TLS", "false").lower() == "true"
        # Never let a blocked port hang the request forever; fail fast instead.
        self.timeout = float(os.getenv("EMAIL_TIMEOUT_SECONDS", "10"))

    def send_email(
        self, *, to_email: str, subject: str, body: str, html_body: str | None = None
    ) -> None:
        if self.brevo_api_key:
            self._send_via_brevo(to_email=to_email, subject=subject, body=body, html_body=html_body)
            return

        self._send_via_smtp(to_email=to_email, subject=subject, body=body, html_body=html_body)

    def _send_via_brevo(
        self, *, to_email: str, subject: str, body: str, html_body: str | None
    ) -> None:
        if not self.from_email:
            raise RuntimeError(
                "Brevo sender is not configured; set SMTP_FROM_EMAIL to a verified Brevo sender"
            )

        payload: dict[str, object] = {
            "sender": {"name": self.from_name, "email": self.from_email},
            "to": [{"email": to_email}],
            "subject": subject,
            "textContent": body,
        }
        if html_body:
            payload["htmlContent"] = html_body

        response = httpx.post(
            BREVO_API_URL,
            json=payload,
            headers={
                "api-key": self.brevo_api_key,
                "accept": "application/json",
            },
            timeout=self.timeout,
        )
        if response.status_code >= 400:
            raise RuntimeError(
                f"Brevo API rejected the email (status={response.status_code}): {response.text}"
            )

    def _send_via_smtp(
        self, *, to_email: str, subject: str, body: str, html_body: str | None
    ) -> None:
        if not self.username or not self.password or not self.from_email:
            raise RuntimeError("SMTP credentials are not configured")

        message = EmailMessage()
        message["Subject"] = subject
        message["From"] = f"{self.from_name} <{self.from_email}>"
        message["To"] = to_email
        message["X-Mailer"] = "Kinder World Mailer"
        message.set_content(body)
        if html_body:
            message.add_alternative(html_body, subtype="html")

        if self.use_ssl:
            with smtplib.SMTP_SSL(self.host, self.port, timeout=self.timeout) as server:
                server.login(self.username, self.password)
                server.send_message(message)
            return

        with smtplib.SMTP(self.host, self.port, timeout=self.timeout) as server:
            if self.use_tls:
                server.starttls()
            server.login(self.username, self.password)
            server.send_message(message)


email_delivery_service = EmailDeliveryService()
