from premsql.agents import BaseLineAgent
from premsql.generators import Text2SQLGeneratorHF
from premsql.agents.tools import SimpleMatplotlibTool
from sqlalchemy import create_engine
import pandas as pd
from premsql.executors.base import BaseExecutor

class MySQLExecutor(BaseExecutor):
    def __init__(self, db_uri: str):
        self.engine = create_engine(db_uri)

    def execute_sql(self, sql: str) -> pd.DataFrame:
        with self.engine.connect() as conn:
            return pd.read_sql_query(sql, conn)


# DB connection
db_uri = "mysql+pymysql://root:Master36%21@localhost:3306/ix_monitor"

print("⏳ Caricamento modello...")
generator = Text2SQLGeneratorHF(
    model_or_name_or_path="premai-io/prem-1B-SQL",
    experiment_name="prem_sql_test",
    device="cpu",
    type="test"
)
print("✅ Modello caricato.")

plotter = SimpleMatplotlibTool()

print("⏳ Inizializzazione agente...")
agent = BaseLineAgent(
    session_name="test_session",
    db_connection_uri=db_uri,
    specialized_model1=generator,
    specialized_model2=generator,
    executor=MySQLExecutor(db_uri),
    plot_tool=plotter
)
print("✅ Agente pronto.")

# Prompt
user_query = input("Scrivi la tua richiesta in italiano:\n> ")
print(f"🧠 Elaborazione richiesta: {user_query}")

response = agent(f"/query {user_query}")
print("✅ Risposta ricevuta!")

try:
    print("\n=== RESPONSE ===\n")
    print(response)
except Exception as e:
    print("Errore:", e)
    print("Oggetto response:", response)
