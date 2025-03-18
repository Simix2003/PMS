import asyncio
from asyncua import Client, ua
from datetime import timedelta, datetime

class OPCClient:
    def __init__(self, url):
        self.url = url
        self.client = Client(url=url, timeout=4)
        self.db_cache = {}

    async def connect(self):
        await self.client.connect()
        print("🟢 OPC Connected")

    async def disconnect(self):
        await self.client.disconnect()
        print("🔴 OPC Disconnected")

    async def _find_node(self, node, path_parts):
        for part in path_parts:
            children = await node.get_children()
            found = False
            for child in children:
                browse = await child.read_browse_name()
                if browse.Name == part:
                    node = child
                    found = True
                    break
            if not found:
                raise Exception(f"❌ Path element '{part}' not found inside '{node}'")
        return node

    async def _find_db(self, db_name):
        if db_name in self.db_cache:
            return self.db_cache[db_name]

        objects_node = self.client.get_objects_node()
        device_set = await objects_node.get_child("2:DeviceSet")
        plcs = await device_set.get_children()

        for plc_node in plcs:
            plc_browse = await plc_node.read_browse_name()
            if "PLC" in plc_browse.Name:
                plc_children = await plc_node.get_children()
                for child in plc_children:
                    child_browse = await child.read_browse_name()
                    if "DataBlocksGlobal" in child_browse.Name:
                        dbs = await child.get_children()
                        for db in dbs:
                            db_browse = await db.read_browse_name()
                            if db_name == db_browse.Name:
                                self.db_cache[db_name] = db
                                return db
        raise Exception(f"DB '{db_name}' not found!")

    async def read(self, db_name, var_path):
        db_node = await self._find_db(db_name)
        path_parts = var_path.split(".")
        var_node = await self._find_node(db_node, path_parts)
        return await self._recursive_read(var_node)

    async def _recursive_read(self, node):
        node_class = await node.read_node_class()
        if node_class == ua.NodeClass.Variable:
            value = await node.read_value()
            return value
        elif node_class == ua.NodeClass.Object:
            struct = {}
            children = await node.get_children()
            for child in children:
                browse = await child.read_browse_name()
                struct[browse.Name] = await self._recursive_read(child)
            return struct
        else:
            raise Exception("Unsupported node class")

    async def write(self, db_name, var_path, var_type, value):
        db_node = await self._find_db(db_name)
        path_parts = var_path.split(".")
        var_node = await self._find_node(db_node, path_parts)
        ua_value = self._convert_to_ua(var_type, value)
        await var_node.write_value(ua_value)
        print(f"✅ WROTE: {db_name}.{var_path} = {value}")

    async def batch_read(self, db_name, var_paths):
        print(f"🚀 Batch Reading {len(var_paths)} variables from {db_name}")
        return {path: await self.read(db_name, path) for path in var_paths}

    async def batch_write(self, db_name, writes):
        print(f"🚀 Batch Writing {len(writes)} variables to {db_name}")
        for item in writes:
            await self.write(db_name, item["var_path"], item["var_type"], item["value"])

    def _convert_to_ua(self, var_type, value):
        var_type = var_type.lower()
        if var_type == "bool":
            return ua.DataValue(ua.Variant(bool(value), ua.VariantType.Boolean))
        elif var_type == "byte":
            return ua.DataValue(ua.Variant(int(value), ua.VariantType.Byte))
        elif var_type == "int":
            return ua.DataValue(ua.Variant(int(value), ua.VariantType.Int16))
        elif var_type == "dint":
            return ua.DataValue(ua.Variant(int(value), ua.VariantType.Int32))
        elif var_type == "real":
            return ua.DataValue(ua.Variant(float(value), ua.VariantType.Float))
        elif var_type == "string":
            return ua.DataValue(ua.Variant(str(value), ua.VariantType.String))
        elif var_type == "char":
            return ua.DataValue(ua.Variant(str(value)[0], ua.VariantType.SByte))
        elif var_type == "time":
            return ua.DataValue(ua.Variant(timedelta(milliseconds=value), ua.VariantType.Duration))
        elif var_type == "dtl":
            return ua.DataValue(ua.Variant(datetime.fromisoformat(value), ua.VariantType.DateTime))
        elif var_type.startswith("array["):
            element_type = var_type[6:-1]
            return ua.DataValue(ua.Variant([self._convert_scalar(element_type, x) for x in value], self._map_variant_type(element_type)))
        else:
            raise Exception(f"Unsupported var_type '{var_type}'")

    def _convert_scalar(self, element_type, value):
        if element_type == "bool":
            return bool(value)
        elif element_type == "byte":
            return int(value)
        elif element_type == "int":
            return int(value)
        elif element_type == "dint":
            return int(value)
        elif element_type == "real":
            return float(value)
        elif element_type == "string":
            return str(value)
        elif element_type == "char":
            return str(value)[0]
        else:
            raise Exception(f"Unsupported scalar type '{element_type}'")

    def _map_variant_type(self, element_type):
        mapping = {
            "bool": ua.VariantType.Boolean,
            "byte": ua.VariantType.Byte,
            "int": ua.VariantType.Int16,
            "dint": ua.VariantType.Int32,
            "real": ua.VariantType.Float,
            "string": ua.VariantType.String,
            "char": ua.VariantType.SByte,
        }
        return mapping.get(element_type, ua.VariantType.String)
