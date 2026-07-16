from datetime import datetime

MAX_SMS_LENGTH = 160


def format_sms(text, add_timestamp=False):
    if add_timestamp:
        now = datetime.now().strftime("%d/%m/%Y %H:%M")
        prefix = f"[{now}] "
        available = MAX_SMS_LENGTH - len(prefix)
        return f"{prefix}{text[:available]}"
    return text[:MAX_SMS_LENGTH]


def preview(text):
    return {
        "original_length": len(text),
        "max_length": MAX_SMS_LENGTH,
        "will_be_truncated": len(text) > MAX_SMS_LENGTH,
        "formatted": format_sms(text),
        "formatted_with_timestamp": format_sms(text, add_timestamp=True),
        "characters_remaining": MAX_SMS_LENGTH - min(len(text), MAX_SMS_LENGTH)
    }
