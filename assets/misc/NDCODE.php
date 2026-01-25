
var nd_ecdc93c9_s = { width: 1000, height: 850 };

if (nd_ecdc93c9_s.width > screen.width - 20) {
    nd_ecdc93c9_s.width = screen.width - 20;
}

if (nd_ecdc93c9_s.height > screen.height - 100) {
    nd_ecdc93c9_s.height = screen.height - 100;
}

//if (console && console.debug) {
//    console.debug(nd_ecdc93c9_s.height);
//}

function ND_TelePAY(CoPID,CoCON,CoSID,CoSYS,CoXID,CoAVS) {
    var NDTelePAYWindow = window.open('http://www.netdebit-telepay.de/CHECK.php?PID='+CoPID+'&CON='+CoCON+'&SID='+CoSID+'&XID='+CoXID+'&AVS='+CoAVS+'','TelePAY','width=' + nd_ecdc93c9_s.width + ',height=' + nd_ecdc93c9_s.height + ',top=10,left=10');
    NDTelePAYWindow.focus();
    return NDTelePAYWindow;
}

function GATE_NDV2(GoVAR1,GoVAR2,GoZAH,GoPOS,GoKUN,GoKNR,GoLANG) {
	return GATE_X('71966', '196602000', '773041366', GoVAR1, GoVAR2, GoZAH, GoPOS, GoKUN, GoKNR,undefined,undefined,undefined,undefined,undefined,undefined,GoLANG);
}

function GATE_NDV2_AMOUNT(GoVAR1,GoVAR2,GoZAH, GoPOS, GoKUN, GoKNR, GoTIM, GoBET, GoLZS, GoLZW, GoVAL) {
	return GATE_X('71966', '196602000', '773041366', GoVAR1,GoVAR2,GoZAH, GoPOS, GoKUN, GoKNR, GoTIM, GoBET, GoLZS, GoLZW, GoVAL);
}

function GATE_POPUP() {
	var name_args = Array('PID', 'CON', 'SID', 'VAR1' ,'VAR2','ZAH', 'POS', 'KUN', 'KNR', 'TIM','BET', 'LZS', 'LZW', 'VAL', 'DC');
	var params ='';
	var url = 'https://www.netdebit-payment.de/buy/init';

    for (var i = 0; i < GATE_POPUP.arguments.length; ++i) {
        if ( typeof(GATE_POPUP.arguments[i]) != "undefined" ) {
            if (i==0)
                params = params+'?'+name_args[i]+'='+escape(GATE_POPUP.arguments[i]);
            else
                params = params+ '&'+name_args[i]+'='+escape(GATE_POPUP.arguments[i]);
		}
	}

	var GateWindow = window.open(url+params,'NetDebit','width='+ nd_ecdc93c9_s.width +',height='+nd_ecdc93c9_s.height+',top=10,left=10,status=yes,scrollbars=yes');
	GateWindow.focus();
	return GateWindow;
}

function GATE_X() {
	name_args = Array('PID', 'CON', 'SID', 'VAR1' ,'VAR2','ZAH', 'POS', 'KUN', 'KNR', 'TIM','BET', 'LZS', 'LZW', 'VAL', 'DC','LANG');
	var params ='';
	var url = 'https://www.netdebit-payment.de/buy/init';

	for (var i = 0; i < GATE_X.arguments.length; ++i){
		if ( typeof(GATE_X.arguments[i]) != "undefined" )
		{
			if (i==0) params = params+'?'+name_args[i]+'='+escape(GATE_X.arguments[i]);
			     else params = params+ '&'+name_args[i]+'='+escape(GATE_X.arguments[i]);
		}
	}

	var GateWindow = window.open(url+params,'NetDebit','width='+ nd_ecdc93c9_s.width +',height='+nd_ecdc93c9_s.height+',top=10,left=10,status=yes,scrollbars=yes');
	GateWindow.focus();
	return GateWindow;
}
