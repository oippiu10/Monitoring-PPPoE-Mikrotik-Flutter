import requests
import json

url = "https://billing.marzuqnetwork.online/api2/payment_operations.php?operation=update"
payload = {
    "router_id": "YOUR_ROUTER_ID",
    "id": 1,
    "user_id": "1",
    "amount": 1000,
    "payment_date": "2026-06-26",
    "method": "cash",
    "note": "",
    "created_by": "Admin"
}
# We don't have the router ID. We can check if it returns 400 or 500 without a real router ID.
response = requests.put(url, json=payload)
print(response.status_code)
print(response.text)
