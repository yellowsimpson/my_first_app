import rclpy
from rclpy.node import Node
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from std_msgs.msg import String, Int32
import threading

app = FastAPI()

# 전역 변수 (최근 주유 정보 저장)
fuel_data = {
    "fuel_type": "경유",
    "amount": 10000,
}

# ROS2 노드 정의
class FuelListener(Node):
    def __init__(self):
        super().__init__('fuel_listener')
        self.subscription = self.create_subscription(
            String,
            '/fuel_info',
            self.listener_callback,
            10
        )

    def listener_callback(self, msg):
        global fuel_data
        try:
            # 메시지 형식: "fuel_type,amount" (예: "휘발유,15000")
            fuel_type, amount = msg.data.split(',')
            fuel_data["fuel_type"] = fuel_type
            fuel_data["amount"] = int(amount)
            self.get_logger().info(f"Received: {fuel_data}")
        except Exception as e:
            self.get_logger().error(f"Parse error: {e}")

# FastAPI 경로
@app.get("/fuel_update")
async def get_fuel_info():
    return fuel_data

# Flutter에서 접근 허용
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ROS2 노드 실행 스레드
def ros2_thread():
    rclpy.init()
    node = FuelListener()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()

if __name__ == "__main__":
    import uvicorn
    ros_thread = threading.Thread(target=ros2_thread, daemon=True)
    ros_thread.start()
    uvicorn.run(app, host="0.0.0.0", port=8000)
