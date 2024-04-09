%populate {
{% UpstreamItfIdx = BDfn.getUpstreamInterfaceIndex();
if (UpstreamItfIdx >= 0 ) : %}
{% if (BD.Interfaces[UpstreamItfIdx].Type == "moca") : %}
    object Ethernet.Link.moca_wan {
{% elif (BD.Interfaces[UpstreamItfIdx].Type == "xpon") : %}
    object Ethernet.Link.eth_xpon {
{% else %}
    object Ethernet.Link.eth_wan {
{% endif; %}
        parameter MACAddress = "$(BASEMACADDRESS)";
    }
{% endif; %}
{% let i = 0 %}
{% for (let Bridge in BD.Bridges) : %}
{% i++ %}
    object Ethernet.Link.bridge_{{lc(Bridge)}} {
        parameter MACAddress = "$(BASEMACADDRESS_PLUS_{{i}})";
    }
{% endfor; %}
{% for ( let Itf in BD.Interfaces ) : if ( Itf.Type == "xpon"  && ( ! Itf.Upstream ) ) : %}
    object Ethernet.Link.eth_xpon {
        parameter MACAddress = "$(BASEMACADDRESS_PLUS_{{i+1}})";
    }
{% endif; endfor; %}
}
