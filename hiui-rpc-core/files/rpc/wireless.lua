local M = {}

local iwinfo = require 'iwinfo'
local ubus = require 'ubus'
local uci = require 'uci'

function M.status()
    local devs = {}

    local conn = ubus.connect()
    local status = conn:call('network.wireless', 'status', {}) or {}
    conn:close()

    for dev_name, dev in pairs(status) do
        if dev.up then
            local typ = iwinfo.type(dev_name)
            if not typ then return end

            local iw = iwinfo[typ]

            devs[dev_name] = {
                type = typ,
                channel = iw.channel(dev_name),
                bitrate = iw.bitrate(dev_name)
            }

            local interfaces = {}

            for _, ifs in ipairs(dev.interfaces) do
                local ifname = ifs.ifname
                interfaces[#interfaces + 1] = {
                    ifname = ifname,
                    ssid = iw.ssid(ifname),
                    mode = iw.mode(ifname),
                    bssid = iw.bssid(ifname),
                    encryption = iw.encryption(ifname)
                }
            end

            devs[dev_name].interfaces = interfaces
        end
    end

    return {devs = devs}
end

function M.stations(param)
    local conn = ubus.connect()
    local status = conn:call('network.wireless', 'status', {}) or {}
    conn:close()

    local stations = {}

    for dev_name, dev in pairs(status) do
        if dev.up then
            local typ = iwinfo.type(dev_name)
            if not typ then break end

            local iw = iwinfo[typ]

            local band = dev.config.band

            local interfaces = {}

            for _, ifs in ipairs(dev.interfaces) do
                local ifname = ifs.ifname
                local assoclist = iw.assoclist(ifname)

                for macaddr, sta in pairs(assoclist) do
                    stations[#stations + 1] = {
                        macaddr = macaddr,
                        ifname = ifname,
                        band = band,
                        signal = sta.signal,
                        noise = sta.noise,
                        rx_rate = {
                            rate = sta.rx_rate,
                            mhz = sta.rx_mhz,
                            mcs = sta.rx_mcs,
                            ht = sta.rx_ht,
                            vht = sta.rx_vht,
                            he = sta.rx_he,
                            nss = sta.rx_nss,
                            short_gi = sta.rx_short_gi,
                            he_gi = sta.rx_he_gi,
                            he_dcm = sta.rx_he_dcm
                        },
                        tx_rate = {
                            rate = sta.tx_rate,
                            mhz = sta.tx_mhz,
                            mcs = sta.tx_mcs,
                            ht = sta.tx_ht,
                            vht = sta.tx_vht,
                            he = sta.tx_he,
                            nss = sta.tx_nss,
                            short_gi = sta.tx_short_gi,
                            he_gi = sta.tx_he_gi,
                            he_dcm = sta.tx_he_dcm
                        }
                    }
                end
            end
        end
    end

    return {stations = stations}
end

function M.staInfo()
    local c = uci.cursor()
    local interface = c:get("wireless", "sta", "network")
    local status = {}
    if interface then
        local conn = ubus.connect()
        status = conn:call('network.interface.' .. interface, 'status', {}) or
                     {}
        conn:close()
        status.name = c:get("wireless", "sta", "ssid")
        status.device = c:get("wireless", "sta", "device")
        status.disabled = c:get("wireless", "sta", "disabled")
    end

    return status
end

function M.getConfig()
    local c = uci.cursor()
    local result = {}
    c:foreach("wireless", "wifi-device", function(s)
        local driver_type = iwinfo.type(s[".name"])
        local htmodelist = iwinfo[driver_type]["htmodelist"](s[".name"])
        local freqlist = iwinfo[driver_type]["freqlist"](s[".name"])
        local hwmodelist = iwinfo[driver_type]["hwmodelist"](s[".name"])
        local txpwrlist = iwinfo[driver_type]["txpwrlist"](s[".name"])
        local encryptions = iwinfo[driver_type]["encryption"](s[".name"])
        s.htmodelist = {}
        for key, value in pairs(htmodelist) do
            if value then table.insert(s.htmodelist, key) end
        end
        s.freqlist = {}
        for key, value in pairs(freqlist) do
            if not value.restricted then
                table.insert(s.freqlist, value.channel)
            end
        end
        s.hwmodelist = {}
        for key, value in pairs(hwmodelist) do
            if value then table.insert(s.hwmodelist, "802.11" .. key) end
        end
        s.interfaces = {}
        c:foreach("wireless", "wifi-iface", function(res)
            if res.device == s[".name"] then
                table.insert(s.interfaces, res)
            end
        end)
        if string.lower(s.band) == "2g" then
            result["wifi_2g"] = s
        elseif string.lower(s.band) == "5g" then
            result["wifi_5g"] = s
        end
    end)
    return result
end

return M
