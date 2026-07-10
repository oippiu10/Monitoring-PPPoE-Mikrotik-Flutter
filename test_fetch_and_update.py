import requests

url_list = "https://billing.marzuqnetwork.online/api2/get_all_users_with_payments.php?router_id=MQN"
res = requests.get(url_list)
data = res.json()
if data.get("success") and data.get("data"):
    # get the first payment
    payment = data["data"][0]
    print("Found payment:", payment)
    
    # Try to update it
    url_update = "https://billing.marzuqnetwork.online/api2/payment_operations.php?operation=update"
    payload = {
        "router_id": payment["router_id"],
        "id": int(payment["id"]),
        "user_id": str(payment["user_id"]),
        "amount": float(payment["amount"]),
        "payment_date": payment["payment_date"],
        "method": "cash",
        "note": "test update via script",
        "created_by": "Admin"
    }
    print("Payload:", payload)
    update_res = requests.put(url_update, json=payload)
    print("Status:", update_res.status_code)
    print("Response:", update_res.text)
else:
    print("No payments found or error", res.text)
