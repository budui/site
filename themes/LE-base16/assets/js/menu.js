function toggledisplay(elementID, buttonID)
{
    (function(style) {
        style.display = style.display === 'none' ? '' : 'none';
    })(document.getElementById(elementID).style);
    var button = document.getElementById(buttonID);
    button.innerHTML = button.innerHTML === "MORE" ? "LESS" : "MORE";
}