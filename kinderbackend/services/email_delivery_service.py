import logging
import os
import smtplib
from email.message import EmailMessage


logger = logging.getLogger(__name__)


class EmailDeliveryService:
    def __init__(self) -> None:
        self.host = os.getenv("SMTP_HOST", "smtp.gmail.com")
        self.port = int(os.getenv("SMTP_PORT", "465"))
        self.username = os.getenv("SMTP_USERNAME", "")
        self.password = os.getenv("SMTP_PASSWORD", "")
        self.from_email = os.getenv("SMTP_FROM_EMAIL") or self.username
        self.from_name = os.getenv("SMTP_FROM_NAME", "Kinder World")
        self.use_ssl = os.getenv("SMTP_USE_SSL", "true").lower() == "true"
        self.use_tls = os.getenv("SMTP_USE_TLS", "false").lower() == "true"

    def send_email(self, *, to_email: str, subject: str, body: str) -> None:
        if not self.username or not self.password or not self.from_email:
            raise RuntimeError("SMTP credentials are not configured")

        message = EmailMessage()
        message["Subject"] = subject
        message["From"] = f"{self.from_name} <{self.from_email}>"
        message["To"] = to_email
        message.set_content(body)

        if self.use_ssl:
            with smtplib.SMTP_SSL(self.host, self.port) as server:
                server.login(self.username, self.password)
                server.send_message(message)
            return

        with smtplib.SMTP(self.host, self.port) as server:
            if self.use_tls:
                server.starttls()
            server.login(self.username, self.password)
            server.send_message(message)


email_delivery_service = EmailDeliveryService()
