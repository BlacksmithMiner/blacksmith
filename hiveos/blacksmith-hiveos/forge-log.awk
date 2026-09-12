function field(line, key,   p, s, c, out) {
    p = index(line, "\"" key "\":")
    if (p == 0) return ""
    s = p + length(key) + 3
    if (substr(line, s, 1) == "\"") s++
    out = ""
    while (s <= length(line)) {
        c = substr(line, s, 1)
        if (c == "," || c == "}" || c == "\"") break
        out = out c; s++
    }
    return out
}
function hms(t,   h, m) { h = int(t/3600); m = int((t%3600)/60); if (h > 0) return h "h" sprintf("%02dm", m); return m "m" sprintf("%02ds", t%60) }
BEGIN { pa = -1; pr = -1; lit = 0 }
{
    line = $0
    if (line !~ /"event":/) { print; next }
    ev = field(line, "event")
    if (ev == "pool_init") {
        printf("  \342\232\222  forge lit \342\200\224 anvil on %s:%s%s\n", field(line,"host"), field(line,"port"), (field(line,"tls")=="1" ? " \302\267 TLS" : ""))
    } else if (ev == "pool_job") {
        if (field(line,"clean") == "1") printf("  \360\237\224\245  new billet \342\200\224 block #%s \302\267 dim %s\n", field(line,"height"), field(line,"dim"))
    } else if (ev == "share") {
        d = field(line,"digest"); printf("  \342\234\246  share hammered \342\200\224 digest %s\342\200\246\n", substr(d,1,14))
    } else if (ev == "pool_stats") {
        a = field(line,"accepted") + 0; r = field(line,"rejected") + 0
        if (pa >= 0 && a > pa) printf("  \342\234\223  share TEMPERED \342\200\224 accepted (total %d)\n", a)
        if (pr >= 0 && r > pr) printf("  \342\234\227  share cracked \342\200\224 rejected, stale/late (total %d)\n", r)
        pa = a; pr = r
        es = field(line,"ep_s_window"); if (es == "") es = field(line,"ep_s")
        up = field(line,"elapsed_s") + 0
        printf("  \342\232\222  %.3f ep/s \302\267 ep %s \302\267 \342\234\223%d \342\234\227%d \302\267 up %s \302\267 %s\n", es+0, field(line,"episodes"), a, r, hms(up), field(line,"gpu"))
    } else if (ev == "pool_stalled") {
        printf("  \342\232\240  quiet pool %ss \342\200\224 relighting the forge\n", field(line,"after_s"))
    } else if (ev == "pool_disconnected") {
        printf("  \342\232\240  bellows dropped \342\200\224 reconnect #%s\n", field(line,"reconnects"))
    } else if (ev == "diag") {
        printf("  \342\226\270  10-min average %.3f ep/s over %s episodes\n", field(line,"avg_ep_s_10min")+0, field(line,"episodes"))
    } else if (ev == "pool_final") {
        printf("  \342\232\222  forge banked \342\200\224 accepted %s, rejected %s\n", field(line,"accepted"), field(line,"rejected"))
    }
}
