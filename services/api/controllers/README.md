# OPC UA Client Standard (Asyncua)

## 🚀 Overview
This is your all-in-one **standard OPC UA client** module designed to work like Snap7 but using OPC UA! Built for modern Python projects with **full async support**.

## ✅ Features
- Connect to Siemens OPC UA Servers (tested on S7-1500)
- Browse to `DeviceSet > PLC > DataBlocksGlobal > DB_NAME`
- Read and write values by specifying only: `(db_name, var_path, var_type)`
- Auto-handles:
  - **Scalars** (`bool`, `int`, `dint`, `real`, `string`, etc.)
  - **Arrays** (`array[bool]`, `array[int]`, etc.)
  - **Nested STRUCTs** (recursively dives into structs!)
  - **Batch Reads/Writes** 🔥
- Built-in OPC UA type conversions 🧙

---

## 🧩 Structure

```python
opc = OPCClient("opc.tcp://192.168.1.1:4840")
await opc.connect()

# READ single value
my_value = await opc.read("DB_READ", "Int")

# READ nested struct
nested = await opc.read("DB_READ", "Struct_1.Struct_Nested.Bool_2")

# READ array
arr = await opc.read("DB_READ", "array")

# WRITE value
await opc.write("DB_WRITE", "Bool", "bool", True)

# BATCH READ
result = await opc.batch_read("DB_READ", ["Int", "Struct_1.Int_1"])

# BATCH WRITE
await opc.batch_write("DB_WRITE", [
  {"var_path": "Int", "var_type": "int", "value": 100},
  {"var_path": "Bool", "var_type": "bool", "value": False}
])

await opc.disconnect()
```

---

## 🧠 Notes for Future You
- **var_path**: accepts simple or nested like `"Struct_1.Struct_Nested.Int_2"`
- **db_name**: is your DB inside DataBlocksGlobal (`DB_READ`, `DB_WRITE`, etc.)
- **var_type**: only required for `.write()` operations (to resolve OPC UA types)
- **read()** auto-detects if the variable is a scalar, array, or struct!

---

## 🧰 Supported Types
- bool
- byte
- int (INT16)
- dint (INT32)
- real (FLOAT)
- string
- char
- time (as timedelta)
- dtl (ISO datetime)
- array[bool], array[int], array[dint], array[string], etc.

---

## 🌌 WHY?
This module is designed for **clean, reusable, plug-and-play OPC UA communication** just like Snap7. Perfect for industrial software or backend services talking to Siemens PLCs.

---

## 👑 Status
**Ready for GANG-LEVEL production 💥**

---


Built by **SIMIX!**

