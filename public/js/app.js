function login() {
    var data = {
        username: $("input[name=username]").val(),
        password: $("input[name=password]").val(),
    };
    $.ajax({
        type: "GET",
        url: ($("input[name=register]").attr("checked")) ?
            "/api/create_account" : "/api/login",
        data: data,
        success: function(reply) {
            var r = jQuery.parseJSON(reply);
            if (r.status == "ok") {
                document.cookie =
                    'auth='+r.auth+
                    '; expires=Thu, 1 Aug 2030 20:00:00 UTC; path=/';
                window.location.href = "/";
            } else {
                $("#errormsg").html(r.error)
            }
        }
    });
    return false;
}
