from locust import HttpUser, task, between

class OnlineBoutiqueUser(HttpUser):
    wait_time = between(1, 3)

    @task(3)
    def browse_products(self):
        self.client.get("/product/1")  # Simulate browsing a product

    @task(1)
    def add_to_cart(self):
        self.client.post("/cart", json={"product_id": 1, "quantity": 1})  # Simulate adding an item to cart
