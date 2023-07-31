var once_per_session = 1


    function get_cookie(Name) {
        var search = Name + "="
        var returnvalue = "";
        if (document.cookie.length > 0) {
            offset = document.cookie.indexOf(search)
            if (offset != -1) { // if cookie exists
                offset += search.length
                // set index of beginning of value
                end = document.cookie.indexOf(";", offset);
                // set index of end of cookie value
                if (end == -1) end = document.cookie.length;
                returnvalue = unescape(document.cookie.substring(offset, end))
            }
        }
        return returnvalue;
    }

    function alertornot() {
        if (get_cookie('alerted') == '') {
            loadalert()
            document.cookie = "alerted=yes"
        }
    }

    function loadalert() {
        document.getElementById("introh").style.visibility = "visible";
    }
if (once_per_session == 0) loadalert()
else alertornot()