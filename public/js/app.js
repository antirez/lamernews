function login() {
    var data = {
        username: $("input[name=username]").val(),
        password: $("input[name=password]").val(),
        register: $("input[name=register]").val()
    };
    $.ajax({
        type: "GET",
        url: "/api/login",
        data: data,
        success: function(reply) {
            r = jQuery.parseJSON(reply);
            if (r.status == "ok") {
                // Set the cookie
                alert("Ok!");
            } else {
                $("#errormsg").html(r.error)
            }
        }
    });
    return false;
}
