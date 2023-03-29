#!/usr/bin/env python3

import re
import paramiko
import unicodedata
import logging
import xml.etree.ElementTree as ET
import os
​
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s -%(levelname)s - %(message)s')
logging.disable(logging.CRITICAL)

assert os.path.exists("tr-181-2-usp-full.xml"), "Need the USP version of the TR-181 DM xml in the same directory"

​
pattern1 = "^(.*)\s+(\(.*\))\s+(Device[\w\.\{\}_-]+).*"
tr181_exclude_list = { "Device.DSL.", "Device.Node", "Device.Fast", "Device.Optical", "Device.Cellular", "Device.ATM", "Device.DOCSIS", "Device.PTM", "Device.HPNA",
                      "Device.Ghn", "Device.HomePlug", "Device.UPA", "Device.ZigBee" ,"Device.LLDP", "Device.IPsec", "Device.GRE", "Device.L2TPv3", "Device.VXLAN",
                      "Device.IEEE8021x", "Device.SmartCardReaders", "Device.DLNA", "Device.FAP", "Device.ProxiedDevice", "Device.XMPP", "Device.BASAPM",
                      "Device.FAST", "Device.Bridging.Filter", "Device.Bridging.ProviderBridge", "Device.FaultMgmt", "Device.CollectionDevice", "Device.LMAP", "Device.WWC",
                      "Device.PDU", "Device.FWE", "Device.ProxiedDeviceNumberOfEntries", "Device.CollectionDeviceNumberOfEntries", "Device.IoTCapabilityNumberOfEntries",
                      "Device.NodeNumberOfEntries", "Device.MQTT.Broker", "Device.STOMP", "Device.IoTCapability", "Device.Standby", "Device.MAP", "Device.Routing.Babel",
                      "Device.IPv6rd", "Device.USB.Interface.{i}.", "Device.DeviceInfo.TemperatureStatus", "Device.Ethernet.LAG.{i}.", "Device.Ethernet.WoL.", 
                      "Device.Ethernet.RMONStats.{i}.", "Device.Ethernet.LAGNumberOfEntries", "Device.Ethernet.RMONStatsNumberOfEntries", "Device.Ethernet.WoLSupported",
                      "Device.UserInterface.Messages.", "Device.UserInterface.LocalDisplay.", "Device.USB.InterfaceNumberOfEntries", "Device.IP.Interface.{i}.TWAMPReflector.{i}.",
                      "Device.IP.Interface.{i}.TWAMPReflectorNumberOfEntries", "Device.IP.ActivePort", "Device.CaptivePortal", "Device.DHCPv4.Relay", "Device.PeriodicStatistics",
                      "Device.QoS.App", "Device.QoS.Flow", "Device.QoS.Policer"}
nbytes = 4096
hostname = "localhost"
port = 22110
​
prplos_dm = {}
tr181_dm  = {}
​
def remove_control_characters(s):
    return "".join(ch for ch in s if unicodedata.category(ch)[0]!="C")
​
def parseXML(xmlfile):
    global tr181_dm
​
    # create element tree object
    tree = ET.parse(xmlfile)
​
    # get root element
    root = tree.getroot()
    # iterate news items
    for item in root.findall('./model/object'):
        tr181_path      = item.attrib['name']
        tr181_status    = "normal"
        if 'status' in item.attrib:
            tr181_status    = item.attrib['status']
            if tr181_status == "deprecated":
                logging.debug("Skipping deprecated object: " + tr181_path)
                continue
​
            if tr181_status == "deleted":
                logging.debug("Skipping deleted object: " + tr181_path)
                continue
        
        key_excluded    = 0
        for key in tr181_exclude_list:
            key = re.escape(key)
            pattern = "^" + key + ".*"
            result = re.findall(pattern, tr181_path)
            if (result):
                key_excluded = 1
​
        if key_excluded:
            continue
​
        data_type       = "unkown"
        permissions     = "unkown"
​
        tr181_dm[tr181_path] = {'tr181_path': tr181_path, 'data_type': data_type, 'permissions': permissions} 
​
        # iterate child elements of item
        for child in item:
            if (child.tag == "parameter"):
                tr181_path      = item.attrib['name'] + child.attrib['name']
                tr181_status    = "normal"
                if 'status' in child.attrib:
                    tr181_status    = child.attrib['status']
                    if tr181_status == "deprecated":
                        logging.debug("Skipping deprecated parameter: " + tr181_path)
                        continue
​
                    if tr181_status == "deleted":
                        logging.debug("Skipping deleted parameter: " + tr181_path)
                        continue
​
                key_excluded    = 0
                for key in tr181_exclude_list:
                    key = re.escape(key)
                    pattern = "^" + key + ".*"
                    result = re.findall(pattern, tr181_path)
                    if (result):
                        key_excluded = 1
                
                if key_excluded:
                    continue
​
                data_type   = "unkown"
                permissions = "unkown"
                tr181_dm[tr181_path] = {'tr181_path': tr181_path, 'data_type': data_type, 'permissions': permissions} 
​
    return
​
def get_prplOS_datamodel_from_file(txtfile):
    global prplos_dm
    f       = open(txtfile)
    lines   = f.readlines()
​
    for string in lines:
        result = re.findall(pattern1, string)
        if (result):
            #replaced = re.sub('\.\d+\.', '.{i}.', result[0])
            permissions = result[0][0]
            data_type   = result[0][1]
            tr181_path  = result[0][2]
            prplos_dm[tr181_path] = {'tr181_path': tr181_path, 'data_type': data_type, 'permissions': permissions} 
​
    return
​
​
def get_prplOS_datamodel():
    global prplos_dm
    ssh = paramiko.Transport((hostname, port))
​
    ssh.connect(username='root', password='sah')
    session = ssh.open_channel(kind='session')
    session.get_pty(term='vt100', width=80, height=24, width_pixels=0, height_pixels=0)
​
    stdout_data = []
    stderr_data = []
​
    session.exec_command('/usr/bin/ubus-cli gsdm -p Device.')
    while True:
        if session.recv_ready():
            buf = session.recv(nbytes).decode("utf8")
            stdout_data.append(buf)
        if session.recv_stderr_ready():
            stderr_data.append(session.recv_stderr(nbytes).decode("utf8"))
        if session.exit_status_ready():
            break
​
    data = ""
    data = data.join(stdout_data)
    for string in data.split("\n"):
        result = re.findall(pattern1, string)
        if (result):
            #replaced = re.sub('\.\d+\.', '.{i}.', result[0])
            permissions = result[0][0]
            data_type   = result[0][1]
            tr181_path  = result[0][2]
            prplos_dm[tr181_path] = {'tr181_path': tr181_path, 'data_type': data_type, 'permissions': permissions} 
​
    session.close()
    ssh.close()
    return
​
parseXML("tr-181-2-usp-full.xml")
get_prplOS_datamodel_from_file("gsdm.txt")
​
print("The following parameters are defined in TR-181 but they are not yet present in prplOS.")
for key in tr181_dm:
    if key not in prplos_dm:
        print("KEY NOT in prplOS: " + key)
​
print("")
print("The following parameters are defined in prplOS but are not present in TR-181.")
print("They should either be changed to a custom vendor parameter or removed from the TR-181 view.")
for key in prplos_dm:
    pattern = ".*X_PRPL-COM.*"
    result = re.findall(pattern, key)
    if result:
        continue
​
    if key not in tr181_dm:
        print("KEY NOT in TR181: " + key)
​
print("")
print("PrplOS vendor specific parameter list.");
for key in prplos_dm:
    pattern = ".*X_PRPL-COM.*"
    result = re.findall(pattern, key)
    if result:
        print("Vendor specific: " + key)
​