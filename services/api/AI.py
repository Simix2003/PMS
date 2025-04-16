from premsql.agents import BaseLineAgent
from premsql.generators import Text2SQLGeneratorHF
from premsql.executors import SQLiteExecutor  # <-- If you're using SQLite, otherwise replace
from premsql.agents.tools import SimpleMatplotlibTool  # ✅ This is the key missing piece!

# Use your actual MySQL connection URI
db_uri = "mysql+pymysql://root:Master36%21@localhost:3306/ix_monitor"

# Initialize the Text-to-SQL generator
generator = Text2SQLGeneratorHF(
    model_or_name_or_path="premai-io/prem-1B-SQL",
    experiment_name="prem_sql_test",
    device="cpu",  # "cuda:0" if using GPU
    type="test"
)

# Use SimpleMatplotlibTool as the required plot_tool
plotter = SimpleMatplotlibTool()

# Initialize the agent
agent = BaseLineAgent(
    session_name="test_session",
    db_connection_uri=db_uri,
    specialized_model1=generator,
    specialized_model2=generator,
    executor=SQLiteExecutor(),  # Or use your actual MySQLExecutor if implemented
    plot_tool=plotter
)

# Prompt the user
user_query = input("Scrivi la tua richiesta in italiano:\n> ")
response = agent(f"/query {user_query}")

# Try to display SQL and table
try:
    print("\n=== RESPONSE ===\n")
    print(response)

except Exception as e:
    print("Errore:", e)
    print("Oggetto response:", response)
