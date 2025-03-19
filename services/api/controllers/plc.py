import asyncio
import re
from asyncua import Client, ua
from datetime import timedelta, datetime

class OPCClient:
    def __init__(self, url):
        self.url = url
        self.client = Client(url=url, timeout=4)
        self.db_cache = {}
        self.subscriptions = {}

    async def connect(self):
        await self.client.connect()
        print("🟢 OPC Connected")

    async def disconnect(self):
        # Unsubscribe all active subscriptions
        for sub_id, sub in list(self.subscriptions.items()):
            try:
                await sub['subscription'].unsubscribe(sub['handle'])
                await sub['subscription'].delete()
                print(f"🚫 Unsubscribed {sub_id}")
            except Exception as e:
                print(f"⚠️ Error unsubscribing {sub_id}: {e}")
        self.subscriptions.clear()

        await asyncio.sleep(0.5)
        try:
            await self.client.disconnect()
            print("🔴 OPC Disconnected")
        except Exception as e:
            print(f"⚠️ Error during disconnect: {e}")

    async def subscribe(self, db_name, var_path, callback, interval_ms=500):
        try:
            db_node = await self._find_db(db_name)
            path_parts = var_path.split(".")
            var_node = await self._find_node(db_node, path_parts)

            handler = SubHandler(callback)
            subscription = await self.client.create_subscription(interval_ms, handler)
            handle = await subscription.subscribe_data_change(var_node)

            sub_id = f"{db_name}.{var_path}"
            self.subscriptions[sub_id] = {
                "subscription": subscription,
                "handle": handle,
                "node": var_node,
                "callback": callback
            }
            print(f"📡 SUBSCRIBED to {sub_id}")

            return sub_id  # return ID for future unsubscription
        except Exception as e:
            print(f"❌ SUBSCRIPTION FAILED: {db_name}.{var_path} | Error: {e}")
            return None

    async def unsubscribe(self, sub_id):
        if sub_id in self.subscriptions:
            sub = self.subscriptions[sub_id]
            await sub['subscription'].unsubscribe(sub['handle'])
            await sub['subscription'].delete()
            del self.subscriptions[sub_id]
            print(f"🚫 UNSUBSCRIBED from {sub_id}")
        else:
            print(f"⚠️ No active subscription for {sub_id}")

    async def _find_node(self, node, path_parts):
        for part in path_parts:
            array_index = None
            array_match = re.match(r"(.+)\[(\d+)]", part)
            if array_match:
                part = array_match.group(1)  # variable name
                array_index = int(array_match.group(2)) - 1  # TIA index -1 for OPCUA

            children = await node.get_children()
            found = False
            for child in children:
                browse = await child.read_browse_name()
                if browse.Name == part:
                    node = child
                    found = True
                    break
            if not found:
                raise Exception(f"❌ Path element '{part}' not found in {node}")

            if array_index is not None:
                # Browse array elements and match adjusted index
                array_children = await node.get_children()
                if array_index < 0 or array_index >= len(array_children):
                    raise Exception(f"❌ Index [{array_index + 1}] out of bounds in {node}")
                node = array_children[array_index]
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
        try:
            db_node = await self._find_db(db_name)
            path_parts = var_path.split(".")
            var_node = await self._find_node(db_node, path_parts)
            value = await self._recursive_read(var_node)
            return value
        except Exception as e:
            print(f"❌ READ FAILED: {db_name}.{var_path} | Error: {e}")
            return None

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
        try:
            db_node = await self._find_db(db_name)
            path_parts = var_path.split(".")
            var_node = await self._find_node(db_node, path_parts)
            ua_value = self._convert_to_ua(var_type, value)
            await var_node.write_value(ua_value)
            return True
        except Exception as e:
            print(f"❌ WRITE FAILED: {db_name}.{var_path} | Error: {e}")
            return False

    async def batch_read(self, db_name, var_paths):
        return {path: await self.read(db_name, path) for path in var_paths}

    async def batch_write(self, db_name, writes):
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
            return ua.DataValue(ua.Variant([self._convert_scalar(element_type, x) for x in value],
                                           self._map_variant_type(element_type)))
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

class SubHandler:
    def __init__(self, user_callback):
        self.user_callback = user_callback

    async def datachange_notification(self, node, val, data):
        await self.user_callback(node, val, data)

    async def event_notification(self, event):
        pass

    async def status_change_notification(self, status):
        print(f"🔄 Subscription status changed: {status}")
