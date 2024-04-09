%populate {
    object Ethernet.Link {
        instance add (Alias = "link_lo", Name = "lo") {
            parameter Enable = "true";
        }
{% UpstreamItfIdx = BDfn.getUpstreamInterfaceIndex();
if (UpstreamItfIdx >= 0 ) : %}
{% if (BD.Interfaces[UpstreamItfIdx].Type == "moca") : %}
        instance add ("moca_wan", Name = "{{BD.Interfaces[UpstreamItfIdx].Name}}") {
            parameter Enable = "true";
{% IntfIndex = BDfn.getInterfaceIndex(BD.Interfaces[UpstreamItfIdx].Name ,"moca");
if (IntfIndex >= 0 ) : %}
            parameter LowerLayers = "Device.MoCA.Interface.{{IntfIndex + 1}}.";
{% endif %}
        }
{% elif (BD.Interfaces[UpstreamItfIdx].Type == "xpon") : %}
        instance add ("eth_xpon", Name = "{{BD.Interfaces[UpstreamItfIdx].Name}}") {
            parameter Enable = "true";
{% IntfIndex = BDfn.getInterfaceIndex(BD.Interfaces[UpstreamItfIdx].Name ,"xpon");
if (IntfIndex >= 0 ) : %}
            parameter LowerLayers = "Device.XPON.ONU.1.EthernetUNI.{{IntfIndex + 1}}.";
{% endif %}
         }
{% else %}
        instance add ("eth_wan", Name = "{{BD.Interfaces[UpstreamItfIdx].Name}}") {
            parameter Enable = "true";
{% IntfIndex = BDfn.getInterfaceIndex(BD.Interfaces[UpstreamItfIdx].Name ,"ethernet");
if (IntfIndex >= 0 ) : %}
            parameter LowerLayers = "Device.Ethernet.Interface.{{IntfIndex + 1}}.";
{% endif %}
        }
{% endif; %}
{% endif; %}
{% let i = 0 %}
{% for (let Bridge in BD.Bridges) : %}
{% i++ %}
        instance add ("bridge_{{lc(Bridge)}}", Name = "{{BD.Bridges[Bridge].Name}}") {
            parameter Enable = "true";
            parameter LowerLayers = "Device.Bridging.Bridge.{{i}}.Port.1.";
        }
{% endfor; %}
{% for ( let Itf in BD.Interfaces ) : if ( Itf.Type == "xpon" && ( ! Itf.Upstream ) ) : %}
        instance add ("eth_xpon", Name = "{{Itf.Name}}") {
            parameter Enable = "true";
            parameter LowerLayers = "Device.XPON.ONU.1.EthernetUNI.1.";
        }
{% endif; endfor; %}
    }
}
