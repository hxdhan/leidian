package main;

use Tk;
use FindBin;
use lib ("$FindBin::RealBin","$FindBin::RealBin/images","$FindBin::RealBin/lib",);
use strict;
use utf8;
use DBI;
use warnings;
use POSIX qw/strftime/;
use 5.010;

use vars qw ($VERSION $top %toplevel $main_menu $year1 $month1 $year2 $month2 $user_f $data_f $f $data_list $device_f $login_f $user $level
$fileMenu $relogin_menuItem $exitMenuItem $dataMenu $receivedata_MenuItem $device_MenuItem $reloaddata_MenuItem $userMenu
$userdata_MenuItem $password_MenuItem $helpMenu $aboutMenuItem $about_f $pwd_f $export_MenuItem $export_f $line_MenuItem $line_f);

$VERSION = sprintf("%d.%02d", q$Revision: 0.50 $ =~ /(\d+)\.(\d+)/);

#以后可能用得到
# use Class::Struct Receive => [
                          # deviceId   => '$',
                          # countId    => '$',
                          # rec_date   => '$',
                          # num        => '$',
			  # ];

BEGIN {
  
    {
	warn $@ if $@;
	eval 'sub M ($) { $_[0] }';
	eval 'sub Mfmt { sprintf(shift, @_) }';
    }
	
}

#数据库初始化
my $db = DBI->connect("dbi:SQLite:data.db", "", "",{RaiseError => 1, AutoCommit => 1});
unless (table_exists($db,"device")) {
    #序列号，防雷点，防雷点备注，计数器，线路号，防雷点顺序
	$db->do("CREATE TABLE device(id INTEGER PRIMARY KEY,device,device_remark,line,device_order)");
}
unless (table_exists($db,"counter")) {
    #序列号，计数器，计数器状态，计数器备注
	$db->do("CREATE TABLE counter(id INTEGER PRIMARY KEY,counter,counter_status,device)");
}

unless (table_exists($db,"receiver")) {
	#序列号，接收器信息，计数器信息，抄录时间，雷击时间
	$db->do("CREATE TABLE receiver (id INTEGER PRIMARY KEY, reciver_s,count_s,recoder_dt,count_dt)");
}

unless (table_exists($db,"line")) {
	#序列号，线路信息，
	$db->do("CREATE TABLE line (id INTEGER PRIMARY KEY, line)");
}
unless (table_exists($db,"user")) {
	#序列号，用户名，密码，等级，加入时间，状态
	$db->do("CREATE TABLE user (id INTEGER PRIMARY KEY, name,password,level,reg_dt,status)");
	#初始化一个用户admin
	my $r_dt = strftime("%Y-%m-%d %H:%M:%S", localtime);
	$db->do("INSERT INTO user VALUES (NULL, 'admin', '12345',0,'$r_dt',1)");
	$db->do("INSERT INTO user VALUES (NULL, 'guest', 'guest',1,'$r_dt',0)");
}



$top = Tk::MainWindow->new(-title => M"雷电计数信息管理系统");
$top->withdraw;
use Tk::Splashscreen;
my $splash = $top->Splashscreen();
my $p = $top->Photo(-file=>'./images/logo.gif');
$splash->Label(-image => $p)->pack;
my $frame1=$splash->Frame(qw/-borderwidth 2 /)->pack(qw/-side top -fill both/);
my $frame2=$splash->Frame(qw/-borderwidth 2 /)->pack(qw/-side top -fill both/);
my $frame3=$splash->Frame(qw/-borderwidth 2 /)->pack(qw/-side top -fill both/);
my $status = $splash->Label->pack(qw/-side bottom -expand 1 -fill x /);
$status->configure(-text=>'请输入用户名和密码～～',-relief => 'groove', -background => '#FFFF99',-font=>'宋体 10');
my $user_field =$frame1->Entry(-font=>'宋体 10',-width=>25,-relief => 'groove')->pack(-side=>'right');
$user_field->focus;
$frame1->Label(-text=>"用户名：", -font=>'宋体 10')->pack(-side=>'right');
my $pw_field=$frame2->Entry(-font=>'宋体 10',-width=>25,-show=>'*',-relief => 'groove')->pack(-side=>'right');
$frame2->Label(-text=>"密  码：", -font=>'宋体 10')->pack(-side=>'right');
$frame3->Button(-text=>' 取消 ',-width=>10,-font=>'宋体 10',-command=>sub{
			
			$splash->withdraw;
			$splash->destroy;
			$top->destroy;
			exit 0;
		})->pack(qw/-side right -padx 5 -pady 5/);
$frame3->Button(-text=>' 确定 ',-width=>10,-font=>'宋体 10',-command=> sub {
	my $u = $user_field->get;
	my $p = $pw_field->get;

	unless ($u ne '' && $p ne '') {
		$status->configure(-text=>'用户名/密码为空～～');
		return;
	}
	my $all_user = $db->selectall_arrayref("SELECT * FROM user WHERE name = '$u' and password = '$p'");
	if(@$all_user) {
		# say "@$user";
		$user = $u;
		$level = @$all_user[0]->[3];
		if($level == 1) {
			$receivedata_MenuItem->configure(-state => 'disabled');
			$device_MenuItem->configure(-state => 'disabled');
			$userdata_MenuItem->configure(-state => 'disabled');
			
		}
		$splash->withdraw;
		$top->deiconify;
		# $top->iconify; 
		
		&show_data;
	}else {
		$status->configure(-text=>'用户名/密码错误～～');
	}

})->pack(-side=>'right',-padx=>5,-pady=>5);
$pw_field->bind('<Return>'=> sub {
		my $u = $user_field->get;
		my $p = $pw_field->get;
	
		unless ($u ne '' && $p ne '') {
			$status->configure(-text=>'用户名/密码为空～～');
			return;
		}
		my $all_user = $db->selectall_arrayref("SELECT * FROM user WHERE name = '$u' and password = '$p'");
		if(@$all_user) {
			
			$user = $u;
			$level = @$all_user[0]->[3];
		
			if($level == 1) {
				$receivedata_MenuItem->configure(-state => 'disabled');
				$device_MenuItem->configure(-state => 'disabled');
				$userdata_MenuItem->configure(-state => 'disabled');
				
			}
			$splash->withdraw;
			$top->deiconify;
			&show_data;
		}else {
			$status->configure(-text=>'用户名/密码错误～～');
		}
	});
$splash->Splash;

$top->optionAdd('*font', '宋体 10');
$top->resizable(0,0);
# $top->Font(-family=> '宋体',  -size  => 9);
#最大化，去掉任务栏
# use Win32Util qw/client_window_region/ ;
# my @extends = Win32Util::client_window_region($top);
# my $width = $extends[2]/2;
# my $height = $extends[3]/2;
# $top->geometry("$width x $height+$extends[0]+$extends[1]");
$top->geometry("950x650+200+50");

# say "@max_extends";
# $top->optionAdd("*font", "-*-arial-normal-r-*-*-*-120-*-*-*-*-*-*");
# $top->optionAdd("*borderWidth", 3);
# $top->geometry(($top->maxsize())[0] .'x'.($top->maxsize())[1]);
# my $screen_h = $top -> screenheight ();
# my $screen_w = $top -> screenwidth ();
# $top -> geometry ($screen_w . "x" . $screen_h);

#菜单
$main_menu = $top->Frame(-relief => 'groove',-borderwidth => 2)->pack(-side => 'top', -fill => 'x');
$fileMenu = $main_menu->Menubutton(-text => '文件',-tearoff => 0,-font=>'宋体 10')->pack(-side => 'left');


$relogin_menuItem = $fileMenu->command(-label => '重新登录',-command => \&new_login,-accelerator => "Ctrl+L",-font=>'宋体 10');
$exitMenuItem = $fileMenu->command(-label => '退出',-command => sub{exit 0 ;} ,-accelerator => "Ctrl+Q",-font=>'宋体 10');

$dataMenu = $main_menu->Menubutton(-text => '数据',-tearoff => 0,-font=>'宋体 10')->pack(-side => 'left');
$receivedata_MenuItem = $dataMenu->command(-label => '采集数据',-command => \&receive_data, -accelerator => "Ctrl+R",-font=>'宋体 10');
$device_MenuItem = $dataMenu->command(-label=>'设备管理',-command => \&device_manage, -accelerator => "Ctrl+D",-font=>'宋体 10');
$line_MenuItem = $dataMenu->command(-label=>'线路管理',-command => \&line, -accelerator => "Ctrl+L",-font=>'宋体 10');
$dataMenu->separator;
$reloaddata_MenuItem = $dataMenu->command(-label=>"重新加载", -command => \&reload_data, -accelerator => "Ctrl+O",-font=>'宋体 10');
$export_MenuItem = $dataMenu->command(-label=>"数据导出", -command => \&export_data, -accelerator => "Ctrl+E",-font=>'宋体 10');

$userMenu = $main_menu->Menubutton(-text => '用户',-tearoff => 0,-font=>'宋体 10')->pack(-side => 'left');
$userdata_MenuItem = $userMenu->command(-label=>"用户管理", -command => \&user_manage, -accelerator => "Ctrl+U",-font=>'宋体 10');
$password_MenuItem = $userMenu->command(-label=>"密码管理", -command => \&pwd_manage, -accelerator => "Ctrl+P",-font=>'宋体 10');

$helpMenu  = $main_menu->Menubutton(-text => '帮助',-tearoff => 0,-font=>'宋体 10')->pack(-side => 'left');
$aboutMenuItem = $helpMenu->command(-label => '关于', -command => \&about,-font=>'宋体 10');

$top->bind("<Control-r>", \&receive_data);
$top->bind("<Control-d>", \&device_manage);
$top->bind("<Control-l>", \&new_login);
$top->bind("<Control-o>", \&reload_data);

# my $main_menu_btn = $top->Frame(-relief => 'groove',-borderwidth => 2)->pack(-side => 'top', -fill => 'x');
# $main_menu_btn->Menubutton(-text=>"采集")->pack( -side => 'left', -padx => 5);

# $main_menu->optionAdd("*font", "-*-arial-normal-r-*-*-*-120-*-*-*-*-*-*");
#字体
$top->optionAdd(-font=>'宋体 10');
$top->configure(-menu => $main_menu);
# user_login($top);

MainLoop;



#重新登录
sub new_login {
	unless (Exists($login_f)) {
		my $db = DBI->connect("dbi:SQLite:data.db", "", "",{RaiseError => 1, AutoCommit => 1});
		$login_f = $top->Toplevel(-takefocus=>1,-title => '重新登录');
		$login_f->resizable(0,0);
		$login_f->focus;
		my $x = $top->rootx();
		my $y = $top->rooty();
		my $xCoord = $x + 200;
		my $yCoord = $y + 100;
		$login_f->geometry("+$xCoord+$yCoord");
		# $login_f->Show( -popover => $top, -overanchor => 'c', -popanchor  => 'c' );
		my $frame1=$login_f->Frame(qw/-borderwidth 2 -relief groove/)->pack(qw/-side top -fill both/);
		my $frame2=$login_f->Frame(qw/-borderwidth 2 -relief groove/)->pack(qw/-side top -fill both/);
		my $frame3=$login_f->Frame(qw/-borderwidth 2 -relief groove/)->pack(qw/-side top -fill both/);
		my $status = $login_f->Label->pack(qw/-side bottom -expand 1 -fill x /);
		$status->configure(-text=>'请输入用户名和密码～～',-relief => 'groove', -background => '#FFFF99',-font=>'宋体 10');
		$frame1->Label(-text=>"用户名：", -width=>20,-font=>'宋体 10')->pack(-side=>'left',-fill=>'x');
		my $user_field =$frame1->Entry(-font=>'宋体 10',-width=>25,-relief => 'groove')->pack;
		$frame2->Label(-text=>"密码：", -width=>20,-font=>'宋体 10')->pack(-side=>'left',-fill=>'x');
		my $pw_field=$frame2->Entry(-font=>'宋体 10',-width=>25,-show=>'*',-relief => 'groove')->pack;
		$frame3->Button(-font=>'宋体 10',-width=>10,-text=>'取消',-command=>sub{
				# $login_f->withdraw;
				# $login_f->grabRelease;
				# $login_f->withdraw;
				$login_f->destroy;
				})->pack(-side=>'right',-padx=>5,-pady=>2);
		$frame3->Button(-font=>'宋体 10',-width=>10,-text=>'确定',-command=> sub {
			my $u = $user_field->get;
			my $p = $pw_field->get;
	
			unless ($u ne '' && $p ne '') {
			$status->configure(-text=>'用户名和密码为空～～');
			return;
			}
			
			my $all_user = $db->selectall_arrayref("SELECT * FROM user WHERE name = '$u' and password = '$p'");
			if(@$all_user) {
				# say "@$user";
				$user = $u;
				$level = @$all_user[0]->[3];
				$login_f->grabRelease;
				$login_f->withdraw;
				if($level == 1) {
				$receivedata_MenuItem->configure(-state => 'disabled');
				$device_MenuItem->configure(-state => 'disabled');
				$userdata_MenuItem->configure(-state => 'disabled');
				
				}
			}else {
				$status->configure(-text=>'用户名/密码错误～～');
			}
			
		})->pack(-side=>'right',-padx=>5,-pady=>2);
		
	}
	else {
		$login_f->deiconify( );
		$login_f->raise( );
	}
}

sub pwd_manage {

	unless (Exists($pwd_f)) {
		my $db = DBI->connect("dbi:SQLite:data.db", "", "",{RaiseError => 1, AutoCommit => 1});
		$pwd_f = $top->Toplevel(-takefocus=>1,-title => '修改密码');
		$pwd_f->resizable(0,0);
		$pwd_f->focus;
		my $x = $top->rootx();
		my $y = $top->rooty();
		my $xCoord = $x + 300;
		my $yCoord = $y + 150;
		$pwd_f->geometry("+$xCoord+$yCoord");
		my $frame1=$pwd_f->Frame(qw/-borderwidth 2 -relief groove/)->pack(qw/-side top -fill both/);
		my $frame2=$pwd_f->Frame(qw/-borderwidth 2 -relief groove/)->pack(qw/-side top -fill both/);
		my $frame3=$pwd_f->Frame(qw/-borderwidth 2 -relief groove/)->pack(qw/-side top -fill both/);
		my $frame4=$pwd_f->Frame(qw/-borderwidth 2 -relief groove/)->pack(qw/-side top -fill both/);
		my $status = $pwd_f->Label->pack(qw/-side bottom -expand 1 -fill x /);
		$status->configure(-text=>'请输入修改密码～～',-relief => 'groove', -background => '#FFFF99',-font=>'宋体 10');
		$frame1->Label(-text=>"当前用户：".$user, -width=>20,-font=>'宋体 10')->pack(-side=>'left',-fill=>'x');
		$frame2->Label(-text=>"密码：", -width=>20,-font=>'宋体 10')->pack(-side=>'left',-fill=>'x');
		my $pw_field=$frame2->Entry(-font=>'宋体 10',-width=>25,-show=>'*',-relief => 'groove')->pack;
		$frame3->Label(-text=>"确认密码：", -width=>20,-font=>'宋体 10')->pack(-side=>'left',-fill=>'x');
		my $pw_field1=$frame3->Entry(-font=>'宋体 10',-width=>25,-show=>'*',-relief => 'groove')->pack;
		$frame4->Button(-font=>'宋体 10',-width=>10,-text=>'取消',-command=>sub{
				# $login_f->withdraw;
				# $login_f->grabRelease;
				# $login_f->withdraw;
				$pwd_f->destroy;
				})->pack(-side=>'right',-padx=>5,-pady=>2);
		$frame4->Button(-font=>'宋体 10',-width=>10,-text=>'确定',-command=>sub{
				my $p1 = $pw_field->get;
				$p1 =~ s/\s+$//g;
				my $p2 = $pw_field1->get;
				$p2 =~ s/\s+$//g;
				unless ($p1 eq $p2) {
					$status->configure(-text=>'密码和确认密码不符合～～');
					return;
				}
				$db->do("UPDATE user set password = '$p1' WHERE name = '$user'");
				$status->configure(-text=>'密码修改完毕～～');
				$pwd_f->bell;
				})->pack(-side=>'right',-padx=>5,-pady=>2);
		
	}else {
		$pwd_f->deiconify();
		$pwd_f->raise();
	}
	
}
#帮助
sub about {
    #my @s = stat($FindBin::RealBin);
	#$aboutMenuItem->configure(-state => 'disabled');
	unless (Exists($about_f)) {
		$about_f = $top->Toplevel(-title => "关于");
		$about_f->focus;
		$about_f->resizable(0,0);
		my $aboutText ="雷电信息管理系统\n\n版本：".$VERSION."\n\n武汉迪克电气设备有限公司出品";
		my $x = $top->rootx();
		my $y = $top->rooty();
		my $xCoord = $x + 200;
		my $yCoord = $y + 100;
		$about_f->geometry("300x150+$xCoord+$yCoord");
		my $topFrame = $about_f->Frame()->pack(-side => 'top');
		my $bottomFrame = $about_f->Frame()->pack(qw/-side bottom -fill x/);
		my $aboutFrame = $topFrame->Frame()->pack(-side => 'left', -padx => 15, -pady => 10);
		my $aboutLabel = $aboutFrame->Label(-text => $aboutText, -justify => 'left',-font=>'宋体 10')->pack(-side => 'top');
		my $closeButton = $bottomFrame->Button( -text => "关闭", -command => sub {
			#$aboutMenuItem->configure(-state => 'active');
			$about_f->destroy(); 
			}, -width => 10,-font=>'宋体 10')->pack(-side => 'top');
		#$about_f->protocol('WM_DELETE_WINDOW',sub{$aboutMenuItem->configure(-state => 'active');$about_f->destroy(); });
		#$t->grabGlobal;
	}else {
		$about_f->deiconify( );
		$about_f->raise( );
	}
}

#接收数据
sub receive_data {

	use Win32::SerialPort;
	use Tk::BrowseEntry;
	use Tk::ROText;
	my $device = "";
	#初始化数据
	my @r_data=();
	
	unless (Exists($data_f)) {
		$data_f = $top->Toplevel(qw/-title 数据采集/);
		my $x = $top->rootx();
		my $y = $top->rooty();
		my $xCoord = $x + 200;
		my $yCoord = $y + 100;
		$data_f->geometry( "+$xCoord+$yCoord" );
		$data_f->resizable(0,0);
		$data_f->focus;
		my $f = $data_f->Frame->pack(qw/-fill both -expand 1/);
		#$f->Frame->pack->Label(-text => "接受数据：")->pack(-side =>'top' );
		my $rot = $f->Scrolled(qw/ROText  -width 35 borderwidth 2 -relief groove -height 15 -scrollbars e /);
		$rot->configure(-font=>'宋体 10');
		$rot->pack(-side => 'left', -fill => 'both');
		
		my $conf_f = $f->Frame->pack(-side => 'left', -anchor => 'nw', -fill => 'y');
		my $ce_f = $conf_f->Frame->pack;
		my $status = $data_f->Label->pack(qw/-side bottom -expand 1 -fill x /);
		$status->configure(-font=>'宋体 10');
		$status->configure(-text => "准备数据采集～～",-relief => 'groove', -background => '#FFFF99');
		
		$ce_f->BrowseEntry(-font=>'宋体 10',-width=>10,-listwidth=>30,-label => '选择端口：', -variable => \$device, -choices => ["COM1", "COM2","COM3","COM4","COM5","COM6","COM7","COM8","COM9","COM10","COM11","COM12","COM13","COM14","COM15","COM16","COM17","COM18","COM19","COM20"])->pack();
		
		$conf_f->Button(-font=>'宋体 10',-text => '连接',-command => sub {
									
									if($device eq "") {
										$status->configure(-text => "没选择端口～～");
										return;
									}
									$status->configure(-text => "准备连接$device ～～");
									my $ob = Win32::SerialPort->new ($device) || $status->configure(-text => "不能连接到$device ，请检查端口连接～～");
									
									configPort ($ob,$status,$device);
									
									my $count_out = $ob ->write("c") || error_message("写入$device 数据错误 ～～",$status);
									
									unless ($count_out) {
										
										error_message("写入错误～～",$status);
										$ob ->close;
										undef $ob;
										return;
									}
									sleep 5;
									
									$ob ->close;
									undef $ob;
									$data_f->bell;
									$status->configure(-text => "$device 连接完毕 ～～");
									})->pack(-fill => 'x',-padx=>5,-pady=>2);
		$conf_f->Button(-font=>'宋体 10',-text => '接收',-command => sub {
									if($device eq "") {
										$status->configure(-text => "没选择端口～～");
										return;
									}
									$status->configure(-text => "准备接收$device 数据～～");
									my $ob = Win32::SerialPort->new ($device) || $status->configure(-text => "不能连接到$device ，请检查端口连接～～");
									
									configPort ($ob,$status,$device);
									
									## send command
									
									my $count_out = $ob ->write("r")|| error_message("写入$device 数据错误 ～～",$status);
									
									unless ($count_out) {
										
										error_message("写入错误～～",$status);
										$ob ->close;
										undef $ob;
										return;
									}
									
									sleep 5;
									
									#read
									use File::Temp qw/mktemp/;
									my $configfile=mktemp("temp.XXXXXX");
									
									$ob->save($configfile);
									#$ob->close;
									#$ob=tie(*FH,'Win32::SerialPort',$configfile);
									
									#sleep 1;
									
									#my $in;
									#raed(FH,$in);
									
									#clear content
									$rot->delete("1.0","end");
									
									#$rot->insert('end', "\n");
									#my $timeout = Win32::GetTickCount()+(1000*60);
									#my $timeout = $ob->get_tick_count+(1000*60);
									my $timeout = 0;
									$ob->read_interval(100);
									$ob->read_const_time(5000);
									$ob->buffers(4096,4096);
									#receive data
									my $t_string = "";
									my $end = "end";
									$ob->are_match("end");
									$ob->lookclear; #clear buffer
																	
									while(1) {
										my $newline = $ob->input;
										$t_string .= $newline;
										#print $t_string;
										#$rot->insert('end', "$newline");
										last if($t_string =~ /$end/ ) ;
										
										if( "" eq $t_string || "" eq $newline) {
											if(0 eq $timeout) {
							
												$timeout = $ob->get_tick_count+(1000*10);
											}else {
												
												 if ($ob->get_tick_count > $timeout) {
													error_message("读取数据错误～～",$status);
													$ob ->close;
													undef $ob;
													unlink $configfile;
													return;
												 }
											}
										}
										sleep 1;
									}
									# format_string ($t_string,$rot);
									#清空数据，否则会重复保存，
									@r_data = ();
									$t_string =~s/rend//;
									my $start;
									foreach my $s (split /r/,$t_string) {
										
										my @ins = split /n/,$s;
										unless ($start) {
											$start = shift @ins;
											$rot->insert('end', "抄录器编号："."$start"."\n");
										}
										
										my $second = shift @ins;
									
										$rot->insert('end', "\n计数器编号："."$second"."\n");
										my $time = shift @ins;
									
										$rot->insert('end',"抄录时间：".format_t($time)."\n");
										$rot->insert('end',"雷击时间：\n");
										my $count =1;
										foreach (@ins) {
											
											$rot->insert('end',"".$count++." ：".format_t($_)."\n");
											push @r_data ,[$start,$second,$time,$_];
										}
									}
									
									unlink $configfile;
									
									$ob ->close;
									undef $ob;
									$data_f->bell;
									$status->configure(-text => "$device 数据接收完毕 ～～");
															
									} )->pack(-fill => 'x',-padx=>5,-pady=>2);
		$conf_f->Button(-font=>'宋体 10',-text => '保存', -command => sub {
										
						my $db = DBI->connect("dbi:SQLite:data.db", "", "",{RaiseError => 1, AutoCommit => 1});
						unless(@r_data) {
							$status->configure(-text => "没有接收数据 ～～");
							return;
						}
						my @fields = (qw(reciver_s count_s recoder_dt count_dt));
						my $fieldlist = join ", ", @fields;
						my $field_placeholders = join ", ", map {'?'} @fields;
						my $insert_query = qq{INSERT INTO receiver ( $fieldlist ) VALUES ( $field_placeholders )};
						my $sth= $db->prepare( $insert_query );
						foreach(@r_data) {
							
							my $data = $db->selectall_arrayref("SELECT * FROM receiver WHERE count_s = '@$_[1]' AND count_dt='@$_[3]' ");
							
							if(@$data) {
								next;
							}
							
							$sth->execute(@$_);
						}
						#清空数据，否则会重复保存，
						@r_data = ();
						$data_f->bell;
						$status->configure(-text => "数据保存完毕 ～～");
										
									})->pack(-fill=>'x',-padx=>5,-pady=>2);
		$conf_f->Button(-font=>'宋体 10',-text => '清除',-command => sub {
									if($device eq "") {
										$status->configure(-text => "没选择端口～～");
										return;
									}
									$status->configure(-text => "准备清除$device 数据～～");
									my $ob = Win32::SerialPort->new ($device) || $status->configure(-text => "不能连接到$device ，请检查端口连接～～");
									configPort ($ob,$status,$device);
									
									$ob ->write("d") || $status->configure(-text => " 写入$device 数据错误 ～～");
									sleep 1;
									$ob ->close;
									undef $ob;
									$data_f->bell;
									$status->configure(-text => "$device 数据清除完毕 ～～");
									
									})->pack(-fill => 'x',-padx=>5,-pady=>2);
		$conf_f->Button(-font=>'宋体 10',-text=>'测试',-command=> sub{
									$rot->delete("1.0","end");
									my $m_string = '00000001n00000001n110526102824n110525143032n110525143033n110525143035n110525143036n110525143037n110525143038n110525143040n110525143041n110525143042n110525143043n110525143045n110525143046n110525143047n110525143048n110525143050n110525143051n110525143052n110525143053n110525143055n110525143056n110525143057n110525143058n110525143100n110525143101n110525143102n110525143103n110525143105n110525143106n110525143107n110525143108n110525143110n110525143111n110525143112n110525143113n110525143115n110525143116n110525143117n110525143118n110525143120n110525143121nrend';
									
									$m_string =~s/rend//;
									my $start;
									foreach my $s (split /r/,$m_string) {
										
										my @ins = split /n/,$s;
										unless ($start) {
											$start = shift @ins;
											$rot->insert('end', "抄录器编号："."$start"."\n");
										}
										my $second = shift @ins;
									
										$rot->insert('end', "\n计数器编号："."$second"."\n");
										my $time = shift @ins;
									
										$rot->insert('end',"抄录时间：".format_t($time)."\n");
										$rot->insert('end',"雷击时间：\n");
										my $count =1;
										foreach (@ins) {
											
											$rot->insert('end',"".$count++." ：".format_t($_)."\n");
											push @r_data ,[$start,$second,$time,$_];
										}
									}
									
									$data_f->bell;
									})->pack(qw/-fill x -padx 5 -pady 2/);
		$conf_f->Button(-font=>'宋体 10',-text=>'取消', -command=>sub{$data_f->destroy;})->pack(qw/-fill x -padx 5 -pady 2/);
	#$t->Popup;
	} else {
		$data_f->deiconify( );
		$data_f->raise( );
	}

}

#信息提示
sub error_message {
	my($msg,$status) = @_;
	$status->configure(-text => "$msg");

}

sub device_extra {
	my @counter = shift @_;
	
}

#格式化采集到的数据时间
sub format_t {
	my $s = shift;
	$s =~ s/(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/20$1年$2月$3日$4时$5分$6秒/;
	return $s;
}
sub short_format_t {
	my $s = shift;
	$s =~ s/(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/20$1-$2-$3 $4:$5:$6/;
	return $s;
}

#config serial port
sub configPort {
	my ($ob,$status,$device) = @_;
	$ob->baudrate(9600)|| $status->configure(-text => "设置$device 参数错误 ～～");
	$ob->parity("none")|| $status->configure(-text => "设置$device 参数错误 ～～");
	## $ob->parity_enable(1);   # for any parity except "none"
	$ob->databits(8)|| $status->configure(-text => "设置$device 参数错误 ～～");
	$ob->stopbits(1)|| $status->configure(-text => "设置$device 参数错误 ～～");
	$ob->handshake('none') || $status->configure(-text => "设置$device 参数错误 ～～");
	$ob->write_settings || $status->configure(-text => "设置$device 参数错误 ～～");
	
}

sub new {bless {} => shift}

#用户登录窗口
# sub user_login {

	# my $top = shift;
	# my $userinfo_w = $top->Toplevel(-takefocus=>1,-title => '请登录');
	# $userinfo_w->bind('<Configure>' => sub {
		# my ($xe) = $userinfo_w->XEvent;
		# $userinfo_w->maxsize($xe->w,$xe->h);
		# $userinfo_w->minsize($xe->w,$xe->h);
	# });
	
	#$userinfo_w->withdraw();
	# $userinfo_w->transient($top);
	#setup frame
	# my $frame1=$userinfo_w->Frame(qw/-borderwidth 2 -relief groove/)->pack(qw/-side top -fill both/);
	# my $frame2=$userinfo_w->Frame(qw/-borderwidth 2 -relief groove/)->pack(qw/-side top -fill both/);
	# my $frame3=$userinfo_w->Frame(qw/-borderwidth 2 -relief groove/)->pack(qw/-side top -fill both/);
	# my $status = $userinfo_w->Label->pack(qw/-side bottom -expand 1 -fill x /);
	# $status->configure(-text=>'请输入用户名和密码～～',-relief => 'groove', -background => '#FFFF99',-font=>'宋体 10');
	# $frame1->Label(-text=>"用户名：", -width=>20,-font=>'宋体 10')->pack(-side=>'left',-fill=>'x');
	# my $user_field =$frame1->Entry(-font=>'宋体 10',-width=>25, -relief => 'groove')->pack;
	# $frame2->Label(-text=>"密码：", -width=>20,-font=>'宋体 10')->pack(-side=>'left',-fill=>'x');
	# my $pw_field=$frame2->Entry(-font=>'宋体 10',-width=>25,-show=>'*',-relief => 'groove')->pack;
	# $pw_field->bind('<Return>'=> sub {
		# my $u = $user_field->get;
		# my $p = $pw_field->get;
	
		# unless ($u ne '' && $p ne '') {
			# $status->configure(-text=>'用户名和密码为空～～');
			# return;
		# }
		# my $all_user = $db->selectall_arrayref("SELECT * FROM user WHERE name = '$u' and password = '$p'");
		# if(@$all_user) {
			# say "@$user
			# $user = $u;
			# $level = @$all_user[0]->[3];
			# $userinfo_w->grabRelease;
			# $userinfo_w->withdraw;
			#shwo level
			# if($level == 1) {
				# $receivedata_MenuItem->configure(-state => 'disabled');
				# $device_MenuItem->configure(-state => 'disabled');
				# $userdata_MenuItem->configure(-state => 'disabled');
				
			# }
			# &show_data;
		# }else {
			# $status->configure(-text=>'用户名/密码错误～～');
		# }
	# });
	# $frame3->Button(-text=>' 取消 ',-font=>'宋体 10',-command=>sub{
			# $userinfo_w->grabRelease;
			# $userinfo_w->withdraw;
			# exit 0;
		# })->pack(qw/-side right -padx 5 -pady 5/);
	# $frame3->Button(-text=>' 确定 ',-font=>'宋体 10',-command=> sub {
		# my $u = $user_field->get;
		# my $p = $pw_field->get;
	
		# unless ($u ne '' && $p ne '') {
			# $status->configure(-text=>'用户名和密码为空～～');
			# return;
		# }
		# my $all_user = $db->selectall_arrayref("SELECT * FROM user WHERE name = '$u' and password = '$p'");
		# if(@$all_user) {
			# say "@$user";
			# $user = $u;
			# $level = @$all_user[0]->[3];
			# $userinfo_w->grabRelease;
			# $userinfo_w->withdraw;
			# if($level == 1) {
				# $receivedata_MenuItem->configure(-state => 'disabled');
				# $device_MenuItem->configure(-state => 'disabled');
				# $userdata_MenuItem->configure(-state => 'disabled');
				
			# }
			# &show_data;
		# }else {
			# $status->configure(-text=>'用户名/密码错误～～');
		# }
	
	# })->pack(-side=>'right',-padx=>5,-pady=>5);
	
	# $userinfo_w->Popup;
	# $user_field->focus;
	# $userinfo_w->protocol('WM_DELETE_WINDOW',sub{;});
	# $userinfo_w->grabGlobal;
		
# }

sub line {
   unless (Exists($line_f)) {
	$line_f = $top->Toplevel(-takefocus=>1,-title=>'线路管理');
	$line_f->focus;
	# $line_f->resizable(0,0);
	
	my $x = $top->rootx();
	my $y = $top->rooty();
	my $xCoord = $x + 300;
	my $yCoord = $y + 100;
	$line_f->geometry("+$xCoord+$yCoord");
	
	
   }
   else {
		$line_f->deiconify( );
		$line_f->raise( );
	}
   
}

#设备管理
sub device_manage {
	use Tk::HList;
	use Tk::DynaTabFrame;
	
	my $db = DBI->connect("dbi:SQLite:data.db", "", "",{sqlite_unicode => 1, RaiseError => 1, AutoCommit => 1});
	my $devices = $db->selectall_arrayref("SELECT * FROM device ORDER BY id");
	my $counts  = $db->selectall_arrayref("SELECT * FROM counter ORDER BY id");
	my $lines   = $db->selectall_arrayref("SELECT * FROM line ORDER BY id");
	
	my @count_toadd = ();
	foreach(@$counts) {
		push  @count_toadd,$_->[1];
	}
	my @lines_toadd = ();
	foreach(@$lines) {
		push  @lines_toadd,$_->[1];
	}
	
	unless (Exists($device_f)) {
		$device_f = $top->Toplevel(qw/-title 设备管理/);
		my $x = $top->rootx();
		my $y = $top->rooty();
		my $xCoord = $x + 150;
		my $yCoord = $y + 100;
		$device_f->geometry( "600x300+$xCoord+$yCoord" );
		# $device_f->resizable(0,0);
		$device_f->focus;
		# $device_f->grabGlobal;
		# $device_f->protocol('WM_DELETE_WINDOW',sub{$device_f->grabRelease;$device_f->destroy;});
		# my $nb_frame = $device_f->Frame()->pack(qw/-fill both/);
			
		my $nb = $device_f->DynaTabFrame(-font=>'宋体 10',-borderwidth=>2,-relief => 'groove')->pack(-side=>'top', -expand => 1, -fill => 'both' ,-padx=>2,-pady=>2);
		
		my $status_frame = $device_f->Frame()->pack(qw/-side bottom -fill both/);
		my $status = $status_frame->Label(-font=>'宋体 10')->pack(qw/-side bottom -expand 1 -fill x /);
		$status->configure(-font=>'宋体 10',-text=>'计数器和防雷点设备的管理～～',-relief => 'groove', -background => '#FFFF99');
				
		my $p3 = $nb->add(
           -caption => '防雷点',
		   -relief => 'groove',
		   -borderwidth=>2,
		   -font=>'宋体 10',
           -hidden => 0
		);
		
		my $p3_frame1 = $p3->Frame()->pack(qw/-side top -fill both/);
		my $p3_frame2 = $p3->Labelframe(-font=>'宋体 10',-text=>"防雷点信息", -relief => 'groove',-borderwidth=>2)->pack(qw/-side top -fill both/);
		
		my $device_lb = $p3_frame1->Scrolled('HList',
		   -header => 1,
		   -columns => 4,
		   -selectmode => 'single',
		   -scrollbars => 'osoe',
		   -selectbackground => 'SeaGreen3',
		   -font=>'宋体 10',
		   -relief => 'groove',
		   -borderwidth=>2,
		   -width=>30,
		   -height=>7,
		  )->pack(qw/-side top -expand 1 -fill both /);
		$device_lb->header('create', 0, -text => '防雷点编号');
		$device_lb->header('create', 1, -text => '计数器');
		$device_lb->header('create', 2, -text => '防雷点备注');
		$device_lb->header('create', 3, -text => '线路号');
		$device_lb->columnWidth(0,100);
		$device_lb->columnWidth(1,100);
		$device_lb->columnWidth(2,200);
		$device_lb->columnWidth(3,100);
		#序列号，防雷点，防雷点备注，计数器，线路号，防雷点顺序
		foreach my $row (@$devices) {
				$device_lb->add(@$row[0], -text => @$row[1]);
				$device_lb->item('create', @$row[0], 1, -text => @$row[3]);
				$device_lb->item('create', @$row[0], 2, -text => @$row[2]);
				$device_lb->item('create', @$row[0], 3, -text => @$row[4]);
		}
		
		my $p3_panel_frame1 = $p3_frame2->Frame()->pack(qw/-side top -fill both/);
		$p3_panel_frame1->Label(-text=>"防雷点编号:", -font=>'宋体 10' )->pack(qw/-side left -padx 5 -pady 10/);
		my $p3_d = $p3_panel_frame1->Entry(-relief => 'groove',-font=>'宋体 10',-width=>10)->pack(qw/-side left -padx 5 -pady 10/);
		my $p3_counter ;
		my $counter_b_s = $p3_panel_frame1->BrowseEntry(-relief => 'groove',-width=>10,-listwidth=>30,-font=>'宋体 10',-label => '计数器：', -variable => \$p3_counter, -choices => \@count_toadd )->pack(qw/-side left -padx 5 -pady 10/);
		my $line ;
		my $line_b_s = $p3_panel_frame1->BrowseEntry(-relief => 'groove',-font=>'宋体 10',-label => '线路号：', -variable => \$line, -choices => \@lines_toadd )->pack(qw/-side left -padx 5 -pady 10/);
		my $p3_panel_frame2 = $p3_frame2->Frame()->pack(qw/-side bottom -fill both/);
		$p3_panel_frame2->Label(-text=>"备注:", -font=>'宋体 10')->pack(qw/-side left -padx 5 -pady 10/);
		my $device_remark = $p3_panel_frame2->Entry(-relief => 'groove',-font=>'宋体 10',-width=>25)->pack(qw/-side left -padx 5 -pady 10/);
		$device_lb->configure(-browsecmd => [sub{
								my $hl = shift;
								my $ent = shift;
								# say $hl;
								# say 'ent '.$ent;
								 # my $data = $hl->info('data',$ent);
								# say $data;
								return unless(defined $ent);
								my $c =  $hl->itemCget($ent,0,-text);
								return unless ($c);
								$c =~ s/\s+$//g;
								$p3_d->delete(0,'end');
								$p3_d->insert(0,$c);
								$p3_counter = $hl->itemCget($ent,1,-text);
								if($p3_counter) {
									$p3_counter =~ s/\s+$//g;
								}
								my $r = $hl->itemCget($ent,2,-text);
							
								$r =~ s/\s+$//g;
								$device_remark->delete(0,'end');
								$device_remark->insert(0,$r);
								$line = $hl->itemCget($ent,3,-text);
								if($line) {
									$line =~ s/\s+$//g;
								}
								
		},$device_lb]);
		$p3_panel_frame2->Button(-font=>'宋体 10',-width=>10,-text=>'删除' , -command => sub{
				
				my $id =  ($device_lb->info('selection'))[0];
				
				unless (defined $id) {
					$status->configure(-text=>'没有选择线路设备号,请先在列表中选择～～');
					return;
				}
				# my $c = $device_lb->itemCget($id,0,-text);
				$db->do("DELETE FROM  device  WHERE id = $id");
				$device_lb->delete('entry',$id);
				
				@$devices = grep {$_->[0] ne $id} @$devices;
				$p3_d->delete(0,'end');
				$device_remark->delete(0,'end');
				undef $p3_counter;
				undef $line;
				$status->configure(-text=>'防雷点信息已经删除～～');
				$device_f->bell;
				
				})->pack(qw/-side right -padx 5 -pady 2/);
		$p3_panel_frame2->Button(-font=>'宋体 10',-width=>10,-text=>'修改' , -command => sub{
				
				my $id =  ($device_lb->info('selection'))[0];
				unless (defined $id) {
					$status->configure(-text=>'没有选择防雷点,请先在列表中选择～～');
					return;
				}
				my $d = $device_lb->itemCget($id,0,-text);
				$d =~ s/\s+$//g;
				my $d1 = $p3_d->get;
				$d1 =~ s/\s+$//g;
				if($d ne $d1) {
					$status->configure(-text=>'防雷点名称不能修改～～');
					return;
				}
				
				my $r = $device_remark->get;
				if($r) {
				$r =~ s/\s+$//g;
				}
				else {
					$r = "";
				}
				if($line ) {
				$line =~ s/\s+$//g;
				}
				else {
					$line = "";
				}
				
				if($p3_counter) {
					$p3_counter =~ s/\s+$//g;
					$p3_counter = substr('00000000'.$p3_counter,-8);
					
					unless(grep {$_->[1] eq $p3_counter } @$counts ) {
						$status->configure(-text=>'填写的计数器无效～～');
						return;
					}
					
					if(grep {$_->[3] eq $p3_counter} @$devices ) {
							$status->configure(-text=>'该计数器已经绑定到其他的防雷器上，～～');
							return;
					}
				}
				else {
				$p3_counter = "";
				}
				
				unless(grep {$_->[1] eq $line} @$lines) {
					$db->do("INSERT INTO line values (NULL,'$line')");
					my $id =  $db->sqlite_last_insert_rowid();
					push @$lines,[$id,$line];
					push @lines_toadd,$line;
				}
				
				$db->do("UPDATE device SET counter = '$p3_counter' ,device_remark = '$r',line = '$line' WHERE id = $id ");
				
				$device_lb->itemConfigure($id,1,-text,$p3_counter);
				$device_lb->itemConfigure($id,2,-text,$r);
				$device_lb->itemConfigure($id,3,-text,$line);
				
				#设置整个数组变量
				
				grep {$_->[0] eq $id and $_->[3] = $p3_counter and $_->[2] = $r} @$devices;
			
				$status->configure(-text=>'防雷点信息修改完毕～～');
				$device_f->bell;
				})->pack(qw/-side right -padx 5 -pady 2/);
		$p3_panel_frame2->Button(-font=>'宋体 10',-width=>10,-text=>'增加' , -command => sub{
				my $d = $p3_d->get;
				$d =~ s/\s+$//g;
				
				if(length $d > 8) {
					$status->configure(-text=>'长度超过8位，请输入8位一下的数据～～');
					return;
				}
				unless ($d) {
					$status->configure(-text=>'请填写设备编号～～');
					return;
				}
				$d = substr('00000000'.$d,-8);
				
				# unless($p3_counter) {
					# $status->configure(-text=>'请填写计数器～～');
					# return;
				# }
				
				if($p3_counter) {
					$p3_counter =~ s/\s+$//g;
					$p3_counter = substr('00000000'.$p3_counter,-8);
					
					unless(grep {$_->[1] eq $p3_counter } @$counts ) {
						$status->configure(-text=>'填写的计数器无效～～');
						return;
					}
					
					if(grep {$_->[3] eq $p3_counter} @$devices ) {
							$status->configure(-text=>'该计数器已经绑定到其他的防雷器上，～～');
							return;
					}
				}
				else {
				$p3_counter = "";
				}
				# say $p3_counter;
				my $r = $device_remark->get;
				$r =~ s/\s+$//g;
				if($line ) {
				$line =~ s/\s+$//g;
				}
				else {
					$line = "";
				}
				# unless ($r) {
					# $status->configure(-text=>'请填写备注～～');
					# return;
				# }
				
				unless(grep {$_->[1] eq $line} @$lines) {
					$db->do("INSERT INTO line values (NULL,'$line')");
					my $id =  $db->sqlite_last_insert_rowid();
					push @$lines,[$id,$line];
					push @lines_toadd,$line;
				}
				
				
				
				# if(exists $device_counter{$d} && $device_counter{$d} ne '' ) {
					# $status->configure(-text=>'该设备已经存在,不能添加～～');
					# return;
				# }
				if(grep{$_->[1] eq $d} @$devices) {
					$status->configure(-text=>'该名称已经存在,不能添加～～');
						return;
				}
				
				$db->do("INSERT INTO device values (NULL,'$d','$r','$p3_counter','$line','')");
				my $id =  $db->sqlite_last_insert_rowid();
				
				$device_lb->add($id, -text =>$d);
			    $device_lb->item('create', $id, 1, -text => $p3_counter);
				$device_lb->item('create', $id, 2, -text => $r);
				$device_lb->item('create', $id, 3, -text => $line);
				
				# $all = $db->selectall_arrayref("SELECT * FROM device ORDER BY id");
			
				push @$devices,[$id,$d,$r,$p3_counter,$line,''];
				$p3_d->delete(0,'end');
				$device_remark->delete(0,'end');
				undef $p3_counter;
				undef $line;
				$status->configure(-text=>'线路设备保存完毕～～');
				$device_f->bell;
		
				})->pack(qw/-side right -padx 5 -pady 2/);
		
		#计数器
		my $p2 = $nb->add(
           -caption => '计数器',
		   -relief => 'groove',
		   -borderwidth=>2,
		   -font=>'宋体 10',
           -hidden => 0
		);
		my $p2_frame1 = $p2->Frame()->pack(qw/-side top -fill both/);
		my $p2_frame2 = $p2->Labelframe(-font=>'宋体 10',-text=>"计数器信息", -relief => 'groove',-borderwidth=>2)->pack(qw/-side top -fill both/);
		# my $p2_frame3 = $p2->Frame()->pack(qw/-side bottom -fill both/);
		my $counter_lb = $p2_frame1->Scrolled('HList',
		   -header => 1,
		   -columns => 3,
		   -selectmode => 'single',
		   -scrollbars => 'osoe',
		   -selectbackground => 'SeaGreen3',
		   -font=>'宋体 10',
		   -relief => 'groove',
		   -borderwidth=>2,
		   -width=>30,
		   -height=>7,
		  )->pack(qw/-side top -expand 1 -fill both /);
		$counter_lb->header('create', 0, -text => '计数器');
		$counter_lb->header('create', 1, -text => '计数器状态');
		$counter_lb->header('create', 2, -text => '计数器备注');
		$counter_lb->columnWidth(0,100);
		$counter_lb->columnWidth(1,150);
		$counter_lb->columnWidth(2,200);
		foreach my $row (@$counts) {
				$counter_lb->add(@$row[0], -text => @$row[1]);
				$counter_lb->item('create', @$row[0], 1, -text => @$row[2]);
				$counter_lb->item('create', @$row[0], 2, -text => @$row[3]);
		
		}
		
		my $p2_panel_frame1 = $p2_frame2->Frame()->pack(qw/-side top -fill both/);
		my $p2_panel_frame2 = $p2_frame2->Frame()->pack(qw/-side bottom -fill both/);
		$p2_panel_frame1->Label(-text=>"计数器:", -font=>'宋体 10' )->pack(qw/-side left -padx 5 -pady 10/);
		my $p2_c = $p2_panel_frame1->Entry(-font=>'宋体 10',-relief => 'groove',-width=>15 )->pack(qw/-side left -padx 5 -pady 10/);
		# my $p2_device = "";
		# $p2_panel_frame1->BrowseEntry(-font=>'宋体 10',-label => '线路设备：', -variable => \$p2_device, -choices => [keys %device_counter] )->pack(qw/-side left -padx 5 -pady 10/);
		my $conter_status = '未安装';
		$p2_panel_frame1->BrowseEntry(-font=>'宋体 10',-relief => 'groove',-state=>'readonly',-label => '计数器状态：', -variable => \$conter_status, -choices => ["未安装", "工作正常/已安装","工作正常/未安装","无应答/已安装","无应答"])->pack(qw/-side left -padx 5/);
		$p2_panel_frame2->Label(-text=>"备注:", -font=>'宋体 10')->pack(qw/-side left -padx 5 -pady 10/);
		my $conter_remark = $p2_panel_frame2->Entry(-font=>'宋体 10',-relief => 'groove',-width=>25 )->pack(qw/-side left -padx 5 -pady 10/);
		$counter_lb->configure(-browsecmd => [sub{
								my $hl = shift;
								my $ent = shift;
								# say $hl;
								# say 'ent '.$ent;
								 # my $data = $hl->info('data',$ent);
								# say $data;
								return unless(defined $ent);
								my $c =  $hl->itemCget($ent,0,-text);
								$c =~ s/\s+$//g;
								$p2_c->delete(0,'end');
								$p2_c->insert(0,$c);
								$conter_status = $hl->itemCget($ent,1,-text);
								$conter_status=~ s/\s+$//g;
								my $r = $hl->itemCget($ent,2,-text);
								$r =~ s/\s+$//g;
								$conter_remark->delete(0,'end');
								$conter_remark->insert(0,$r);
								
		},$counter_lb]);
		
		$p2_panel_frame2->Button(-font=>'宋体 10',-width=>10,-text=>'删除' , -command => sub{
				my $id =  ($counter_lb->info('selection'))[0];
				unless (defined $id) {
					$status->configure(-text=>'没有选择计数器,请先在列表中选择～～');
					return;
				}
				
				my $c = $counter_lb->itemCget($id,0,-text);
				$c =~ s/\s+$//g;
				# if ( $counter_device{$c} ne '') {
					# $status->configure(-text=>'不能删除，请先删除该计数器绑定的设备～～');
					# return;
				# }
			
				my $data = $db->selectall_arrayref("SELECT * FROM receiver WHERE count_s = '$c' LIMIT 1");
				if(@$data) {
					$status->configure(-text=>'该计数器有记录数据，不能删除～～');
					return;
				}
				
				$db->do("DELETE FROM counter WHERE id = $id");
				$db->do("UPDATE device set counter = '' WHERE counter = '$c'");
				
				$counter_lb->delete('entry',$id);
				say "@$counts";
				@$counts = grep {$_->[0] ne $id} @$counts;
				
				@count_toadd = ();
				unless (@$counts) {
				foreach(@$counts) {
					push  @count_toadd,$_->[1];
				}
				}
				
				$counter_b_s->configure(-choices => \@count_toadd );
				$p2_c->delete(0,'end');
				$conter_remark->delete(0,'end');
				$conter_status = '未安装';
				$status->configure(-text=>'计数器已经删除～～');
				$device_f->bell;
				
				})->pack(qw/-side right -padx 5 -pady 2/);
		$p2_panel_frame2->Button(-font=>'宋体 10',-width=>10,-text=>'修改' , -command => sub{
				my $id =  ($counter_lb->info('selection'))[0];
				
				unless (defined $id) {
					$status->configure(-text=>'没有选择计数器，请从列表中选择一个～～');
					return;
				}
				unless ($conter_status) {
					$status->configure(-text=>'选择一个计数器状态～～');
					return;
				}
				my $c = $counter_lb->itemCget($id,0,-text);
				$c =~ s/\s+$//g;
				my $c1 = $p2_c->get;
				$c1 =~ s/\s+$//g;
				if($c ne $c1) {
					$status->configure(-text=>'选择的计数器编号不能修改，～～');
					return;
				}
				
				my $r = $conter_remark->get;
				$r =~ s/\s+$//g;
				
				$conter_status =~ s/\s+$//g;
				
				$db->do("UPDATE count SET counter_status = '$conter_status' ,counter_remark = '$r' WHERE id = $id");
				
				$counter_lb->itemConfigure($id,1,-text,$conter_status);
				$counter_lb->itemConfigure($id,2,-text,$r);
				
				grep {$_->[0] eq $id and $_->[2] = $conter_status and $_->[3] = $r} @$counts;			
				
				$status->configure(-text=>'计数器修改完毕～～');
				$device_f->bell;
				})->pack(qw/-side right -padx 5 -pady 2/);
		$p2_panel_frame2->Button(-font=>'宋体 10',-width=>10,-text=>'增加' , -command => sub{
				my $c = $p2_c->get;
				$c =~ s/\s+$//g;
				if(length $c > 8) {
					$status->configure(-text=>'计数器长度超过8位～～');
					return;
				}
				unless ($c) {
					$status->configure(-text=>'请填写计数器～～');
					return;
				}

				$c = substr('00000000'.$c,-8);
				
				my $r = $conter_remark->get;
				$r =~ s/\s+$//g;
				
				if(grep {$_->[1] eq $c} @$counts) {
					$status->configure(-text=>'计数器已经存在，不能添加～～');
					return;
				}
				
				$db->do("INSERT INTO counter  VALUES (NULL,'$c','$conter_status','$r')");
				my $id =  $db->sqlite_last_insert_rowid();
				$counter_lb->add($id, -text =>$c);
			    $counter_lb->item('create', $id, 1, -text => $conter_status);
				$counter_lb->item('create', $id, 2, -text => $r);
		
				push @$counts,[$id,$c,$conter_status,$r];
				push @count_toadd,$c;
			
				$counter_b_s->configure(-choices => \@count_toadd );
				$status->configure(-text=>'计数器保存完毕～～');
				
				
				})->pack(qw/-side right -padx 5 -pady 2/);
		
	}else {
    $device_f->deiconify( );
    $device_f->raise( );
  }
	
	
}
#用户管理，增加用户
sub user_manage {
	use Tk::HList;
	use DBI;
	use feature 'say';
	
	my $db = DBI->connect("dbi:SQLite:data.db", "", "",{RaiseError => 1, AutoCommit => 1});
	#如果表不存在，应该考虑重新设计
	
	my $all = $db->selectall_arrayref("SELECT * FROM user ORDER BY id ");

	#等级和编码对应的map
	my %levels = ('管理员'=>0,'一般用户'=>1);
	#编码和登记对应的map
	my %r_levels = reverse %levels;
	
	unless (Exists($user_f)) {
		$user_f = $top->Toplevel(qw/-takefocus 1 -title 用户管理/);
		my $x = $top->rootx();
		my $y = $top->rooty();
		my $xCoord = $x + 150;
		my $yCoord = $y + 100;
		$user_f->geometry( "+$xCoord+$yCoord" );
		$user_f->resizable(0,0);
		$user_f->focus;
		my $status = $user_f->Label->pack(qw/-side bottom -expand 1 -fill x /);
		$status->configure(-text => "用户的增加和删除～～",-font=>'宋体 10',-relief => 'groove', -background => '#FFFF99');
		my $f = $user_f->Frame->pack(qw/-fill both -expand 1 -padx 2 -pady 2/);
		my $u_lb = $f->Scrolled('HList',
			   -header => 1,
			   -columns => 3,
			   -selectmode => 'single',
			   -scrollbars => 'osoe',
			   -font=>'宋体 10',
			   -borderwidth=>2,
			   -relief => 'groove',
			   -width => 70,
			   -height => 7,
			   -selectbackground => 'SeaGreen3',
			  )->pack(qw/-side left -expand 1 -fill both /);
		
		$u_lb->columnWidth(1,100);
		
		

		my $hl = $u_lb->Subwidget('scrolled');
		my(@bt) = $hl->bindtags; @bt[1,0] = @bt[0,1]; $hl->bindtags(\@bt);
		$u_lb->header('create', 0, -text => '用户名');
		$u_lb->header('create', 1, -text => '等级');
		$u_lb->header('create', 2, -text => '更新时间');
		
	
	foreach my $row (@$all) {
		$u_lb->add(@$row[0], -text => @$row[1].' ' x 10);
		$u_lb->item('create', @$row[0], 1, -text => $r_levels{@$row[3]});
		$u_lb->item('create', @$row[0], 2, -text => @$row[4].' ' x 10);
	
	}

	my $adduser_f = $user_f->Frame->pack(qw/-fill both -expand 1 -padx 2/);
	
	my $adduser_p = $adduser_f->Labelframe(-font=>'宋体 10',-text=>"用户信息", -relief => 'groove',-borderwidth=>2)->pack(qw/-fill both -expand 1/);
	my $frame1 = $adduser_p->Frame()->pack(qw/-side top -fill both -expand 1/);
	my $frame2 = $adduser_p->Frame()->pack(qw/-side bottom -fill both -expand 1/);
	
	$frame1->Label(-font=>'宋体 10',-text=> "用户名:" )->pack(qw/-side left -padx 5 -pady 5/);
	my $u =$frame1->Entry(-font=>'宋体 10',-relief => 'groove',-width=>15 )->pack(qw/-side left -padx 5 -pady 5/);
	$frame1->Label(-font=>'宋体 10',-text=> "密码: ")->pack(qw/-side left -padx 5 -pady 5/);
	my $p =$frame1->Entry(-font=>'宋体 10',-relief => 'groove',-width=>15,-show=>'*')->pack(qw/-side left -padx 5 -pady 5/);
	$frame1->Label(-font=>'宋体 10',-text=> "确认密码:")->pack(qw/-side left -padx 5/);
	my $cp =$frame1->Entry(-font=>'宋体 10',-relief => 'groove',-width=>15,-show=>'*')->pack(qw/-side left -padx 5/);
	my $level = '一般用户';
	$frame2->BrowseEntry(-font=>'宋体 10',-relief => 'groove',-label => '等级:', -variable => \$level, -choices => ["管理员", "一般用户"])->pack(qw/-side left -padx 5/);
	
	$u_lb->configure(-browsecmd => [sub{
								my $hl = shift;
								my $ent = shift;
								# say $hl;
								# say 'ent '.$ent;
								 # my $data = $hl->info('data',$ent);
								# say $data;
								return unless(defined $ent);
								my $username =  $hl->itemCget($ent,0,-text);
								$username =~ s/\s+$//g;
								$u->delete(0,'end');
								$u->insert(0,$username);
								# say $username;
								my $pwd;
								foreach my $row (@$all) {
									if(@$row[1] eq $username) {
										$pwd = @$row[2];
										last;
									}
								}
								
								$p->delete(0,'end');
								$p->insert(0,$pwd);
								$cp->delete(0,'end');
								$cp->insert(0,$pwd);
								$level = $hl->itemCget($ent,1,-text);
								# $level =~ s/\s+$//g;
								
								
		},$u_lb]);
	
	$frame2->Button(-font=>'宋体 10',-width=>10,-text=>'删除', -command => sub {
		my $id =  ($u_lb->info('selection'))[0];
		
		unless (defined $id) {
			$status->configure(-text => "没有选择，请在列表中重新选择用户～～");
			return;
		}
		my $username = $u_lb->itemCget($id,0,-text);
		$username =~ s/\s+$//g;
		if($username eq 'admin') {
			 $status->configure(-text => "管理员不能删除～～");
			 return;
		}
		$u_lb->delete('entry',$id);
		
		$db->do("DELETE FROM  user WHERE ID = $id");
		
		
		foreach my $row (@$all) {
			if(@$row[0] eq $id) {
				@$row = ();
				last;
			}
	
		}
		
		$status->configure(-text => "用户已经删除～～");
		$user_f->bell;
	})->pack(qw/-side right -padx 5 /);
	$frame2->Button(-font=>'宋体 10',-width=>10,-text=>'修改', -command => sub {
		my $id =  ($u_lb->info('selection'))[0];
		
		unless (defined $id) {
			$status->configure(-text => "没有选择，请在列表中重新选择用户～～");
			return;
		}
		
		my $username =  $u_lb->itemCget($id,0,-text);
		$username =~ s/\s+$//g;
		
		my $username1 = $u->get;
		$username1 =~ s/\s+$//g;
		if($username ne $username1) {
			$status->configure(-text => "用户名不能修改～～");
			return;
		}
		my $password = $p->get;
		$password =~ s/\s+$//g;
		
		unless ($username ne '' && $password ne '') {
			$status->configure(-text => "用户名/密码为空～～");
			return;
		}
		my $password1 = $cp->get;
		$password1 =~ s/\s+$//g;
		unless ($password eq $password1) {
			$status->configure(-text => "密码和确认密码不相同～～");
			return;
		}
		my $r_dt = strftime("%Y-%m-%d %H:%M:%S", localtime);
		$db->do("UPDATE user set password = '$password',level = $levels{$level},reg_dt = '$r_dt' WHERE id = $id");
		
		$u_lb->itemConfigure($id,1,-text,$level);
		$u_lb->itemConfigure($id,2,-text,$r_dt);
		
		foreach my $row (@$all) {
			if(@$row[0] eq $id) {
				@$row[3] = $level;
				@$row[4] = $r_dt;
				last;
			}
	
		}
		
		$status->configure(-text => "用户信息已经修改～～");
		$user_f->bell;
	})->pack(qw/-side right -padx 5 /);
	$frame2->Button(-font=>'宋体 10',-text=>'增加' ,-width=>10,-command => sub {
		my $username = $u->get;
		$username =~ s/\s+$//g;
		my $password = $p->get;
		$password =~ s/\s+$//g;
		# say $cp->get;
		unless ($username ne '' && $password ne '') {
			$status->configure(-text => "用户名/密码为空～～");
			return;
		}
		my $password1 = $cp->get;
		$password1 =~ s/\s+$//g;
		if($password ne $password1) {
			$cp->delete(0,'end');
			$p->delete(0,'end');
			$status->configure(-text => "密码和确认密码不相同～～");
			return;
		}
		foreach my $row (@$all) {
			if(@$row[1] eq $username) {
				$status->configure(-text => "该用户已经添加了～～");
				return;
			}
	
		}
		
		my $r_dt = strftime("%Y-%m-%d %H:%M:%S", localtime);
		$db->do("INSERT INTO user VALUES (NULL, '$username', '$password',$levels{$level},'$r_dt',1)");
		my $id = $db->sqlite_last_insert_rowid();
		$u_lb->add($id, -text => $username.' ' x 20);
		$u_lb->item('create', $id, 1, -text => $level.' ' x 20);
		$u_lb->item('create', $id, 2, -text => $r_dt.' ' x 20);
		
		
		$cp->delete(0,'end');
		$p->delete(0,'end');
		$u->delete(0,'end');
		push @$all,[$id,$username,$password,$level,$r_dt,1];
		
		# foreach my $row (@$all) {
			# say @$row[0].@$row[1].@$row[2];
		# }
		
		$status->configure(-text => "用户增加完毕～～");
		$user_f->bell;
		
		
	})->pack(qw/-side right -padx 5 /);
	
	   
  } else {
    $user_f->deiconify( );
    $user_f->raise( );
  }
	# my $t = $top->Toplevel(qw/-takefocus 1 -title 用户管理/);
	# $t->bind('<Configure>' => sub {
		# my ($xe) = $t->XEvent;
		# $t->maxsize($xe->w,$xe->h);
		# $t->minsize($xe->w,$xe->h);
	# });
	# $t->transient($top);
	
	
	 # $t->Popup;
	# $t->focus;
	# $t->protocol('WM_DELETE_WINDOW',sub{;});
	# $t->grabGlobal;
}

sub reload_data {
	use Date::Calc qw(:all); 
	use POSIX qw/strftime/;
	use feature 'say';
	use DBI;
	
	my $db = DBI->connect("dbi:SQLite:data.db", "", "",{sqlite_unicode => 1, RaiseError => 1, AutoCommit => 1});
	if (Exists($f)) {
		# foreach($f->children) {
		#foreach($_->children) {
			# say $_->cget(-text);
		# $_->packForget;
		# $_->destroy;
		#}
		# }
		$f->destroy;
	
	
	}
	&show_data();
}

#显示数据,根据设备号显示日期，然后再该日期显示雷击信息
sub show_data {
	use Date::Calc qw(:all); 
	use Tk::DateEntry;
	use POSIX qw/strftime/;

	use feature 'say';
	use DBI;
	
	my $db = DBI->connect("dbi:SQLite:data.db", "", "",{sqlite_unicode => 1, RaiseError => 1, AutoCommit => 1});
	my $device = $db->selectall_arrayref("select * from device ");
	my $lines = $db->selectall_arrayref("select * from line ");
	unless (Exists($f)) {
		$f = $top->Frame->pack(qw/-fill both -expand 1 -ipadx 5 -ipady 10/);
		
		my $left_f = $f->Frame->pack(qw/-fill both -side left -ipadx 2 -ipady 2 -padx 2 -pady 2/);
		
		my $right_f = $f->Frame->pack(qw/-fill both -ipadx 2 -ipady 2/);
		
		my $count_list = $left_f->Scrolled(qw/HList -separator . -drawbranch 1 -selectmode single -columns 2 -indent 20
			 -scrollbars e -selectbackground SeaGreen3/
			)->pack(qw/-side left -fill both -expand 1 -ipadx 5 -ipady 5 /);
		$count_list->configure(-font=>'宋体 10',-relief => 'groove',-borderwidth=>2);
		$data_list = $f->Scrolled(qw/HList -header 1 -columns 5 -selectbackground SeaGreen3 -scrollbars e /);
		$data_list->configure(-font=>'宋体 10',-relief => 'groove',-borderwidth=>2);
		my $left_data;
		$count_list->configure( -browsecmd => [ sub
								   {
								   
									my $hl = shift;
									my $ent = shift;
									# say $hl;
									# say 'ent '.$ent;
									# my $data = $hl->info('data',$ent);
									return unless (defined $ent);
									
									$left_data =  $hl->info('data',$ent);
									my %device_all = map {$_->[3] =>$_->[1]} @$device;
									my $all = ();
									if ($left_data) {
										
										# say $left_data;
										
										# my %rd = reverse %device_all;
										# $rd{$left_data} ='' unless(exists $rd{$left_data});
										$all = $db->selectall_arrayref("SELECT * FROM receiver WHERE count_s = '$left_data' ORDER BY count_dt DESC ");
									}
									$data_list->delete('all');
									foreach my $row (@$all) {
										$device_all{@$row[2]} = '' unless(exists $device_all{@$row[2]});
										$data_list->add(@$row[0], -text => $device_all{@$row[2]});
										$data_list->item('create', @$row[0], 1, -text => short_format_t(@$row[4]));
										$data_list->item('create', @$row[0], 2, -text => @$row[2]);
										$data_list->item('create', @$row[0], 3, -text => short_format_t(@$row[3]));
										$data_list->item('create', @$row[0], 4, -text => @$row[1]);
									}
									# say 'data'."$data";
									# foreach ($hl,$ent,$data)
									 # {
									  # print ref($_) ? "ref $_\n" : "string $_\n";
									 # }
									# print "\n";
								   }, $count_list
								 ]
				   );
		$count_list->add(1, -text => '线路设备' );
		
		# my %r = map {$_->[4] =>1} @$device;
		# my @distinct_elems = sort keys %r;
		foreach my $row (@$lines) {
			$count_list->add("1.".$row->[0], -text => @$row[1]) if (@$row[1] ne '');
			foreach (@$device) {
				if($_->[4] eq $row->[1]) {
					$count_list->add("1.".$row->[0].".".$_->[0], -text => $_->[1],-data => $_->[3]) if ($_->[1] ne '');
				}
			}
		}
		
		
		my ($year,$month,$day) = split('-',strftime("%Y-%m-%d", localtime));
		
		# say $year.$month.$day;
		
		my $t_f = $right_f->Frame()->pack(-side=>'top', -expand=>1, -fill=>'x',-ipadx=>10,-ipady=>10);
		
		my $l_m = $t_f->Labelframe(-font=>'宋体 10',-relief => 'groove',-text=>"数据查询", -borderwidth=>2)->pack( -expand => 1, -fill => 'both',-padx=>5,-pady=>5,-ipadx=>5,-ipady=>5);
		my $status = $l_m->Label->pack(qw/-side bottom -expand 1 -fill x /);
		$status->configure(-text=>'请选择查询日期～～',-relief => 'groove', -background => '#FFFF99',-font=>'宋体 10');
		my $l_m1 = $l_m->Frame()->pack(-side=>'top', -expand=>1, -fill=>'x');
		$l_m1->Label(-text=>'请选择雷击起始日期：',,-font=>'宋体 10')->pack(qw/-side left  -fill x -ipadx 10/);
		my $l_m2 = $l_m->Frame()->pack(-side=>'top', -expand=>1, -fill=>'x');
		$l_m2->Label(-text=>'开始日期：',-font=>'宋体 10')->pack(qw/-side left  -fill x -ipadx 10 /);
		 my $start_dt=$l_m2->DateEntry
                (-weekstart=>0,
				-width => 20,
				-font =>'宋体 10',
				-headingfmt=> '%m/%Y',
                 -daynames=>[qw/日 一 二 三 四 五 六 /],
                 -parsecmd=>sub {
                        my ($d,$m,$y) = ($_[0] =~ m/(\d*)\/(\d*)-(\d*)/);
                        return ($y,$m,$d);
                 },
                 -formatcmd=>sub {
                        sprintf ("%d-%02d-%02d",$_[0],$_[1],$_[2],);
                 }
                )->pack(qw/-side left/);
		$l_m2->Label(-text=>'结束日期：',-font=>'宋体 10')->pack(qw/-side left  -fill x -ipadx 10/);
		 my $end_dt=$l_m2->DateEntry
                (-weekstart=>0,
				-headingfmt=> '%m/%Y',
				-font =>'宋体 10',
				-width => 20,
                 -daynames=>[qw/日 一 二 三 四 五 六 /],
                 -parsecmd=>sub {
                        my ($d,$m,$y) = ($_[0] =~ m/(\d*)\/(\d*)-(\d*)/);
                        return ($y,$m,$d);
                 },
                 -formatcmd=>sub {
                        sprintf ("%d-%02d-%02d",$_[0],$_[1],$_[2],);
                 }
                )->pack(qw/-side left/);
		
		my $data_f=$right_f->Frame()->pack(-side=>'top', -expand=>1, -fill=>'both');
		
		$data_list->pack(-expand=>1, -fill=>'both');
		$data_list->header('create', 0, -text => '防雷点名称');
		$data_list->header('create', 1, -text => '雷击时间');
		$data_list->header('create', 2, -text => '计数器编号');
		$data_list->header('create', 3, -text => '抄录时间');
		$data_list->header('create', 4, -text => '读写器编号');
		$data_list->columnWidth(0,100);
		$data_list->columnWidth(1,200);
		$data_list->columnWidth(2,100);
		$data_list->columnWidth(3,200);
		$data_list->columnWidth(4,100);
		$data_f->Advertise(HList => $data_list);
		
		my %device_all = map {$_->[3] =>$_->[1]} @$device;
		my $start = substr($year,2).substr('0'.$month,-2).substr('0'.$day,-2).'000000';
		my $end = substr($year,2).substr('0'.$month,-2).substr('0'.$day,-2).'235959';
		my $all = $db->selectall_arrayref("SELECT * FROM receiver WHERE count_dt between '$start' and '$end' ORDER BY count_dt DESC ");
		foreach my $row (@$all) {
			$device_all{@$row[2]} = '' unless(exists $device_all{@$row[2]});
			$data_list->add(@$row[0], -text => $device_all{@$row[2]});
			$data_list->item('create', @$row[0], 1, -text => short_format_t(@$row[4]));
			$data_list->item('create', @$row[0], 2, -text => @$row[2]);
			$data_list->item('create', @$row[0], 3, -text => short_format_t(@$row[3]));
			$data_list->item('create', @$row[0], 4, -text => @$row[1]);
		}
		
		$l_m2->Button(-font=>'宋体 10',-width=>10,-text=>'导出',-command=>sub{
				use Spreadsheet::WriteExcel;  
				my $s = $start_dt->get;
				my $e = $end_dt->get;
				$s =~ s/\s+$//g;
				$e =~ s/\s+$//g;
				unless ($s ne ''  && $e ne '') {
					$status->configure(-text=>'请选择查询日期');
					return;
				}
				my $types = [ ['excel files', '.xls'],
				['All Files',   '*'],];
				my $file = $l_m2->getSaveFile(-title=>'导出文件',-filetypes => $types,-defaultextension => '.xls'); 
				return unless $file;
				# $status->configure(-text=>" $file");
				
				my $ansi_path = Win32::GetANSIPathName($file);
				my $workbook = Spreadsheet::WriteExcel->new($ansi_path); 
				my $worksheet = $workbook->add_worksheet();  
				my $format = $workbook->add_format();
				my $bold = $workbook->add_format(bold => 1);
				$worksheet->set_row(0, 20, $bold);
				$worksheet->set_column('D:E', 30);
				  
				
				my @headings = ('防雷点名称','雷击时间','计数器编号','抄录时间','读写器编号');
				$worksheet->write('A1', \@headings);
		
				
				my ($sy,$sm,$sd) = split('-',$s);
				my ($ey,$em,$ed) = split('-',$e);
				my $start = substr($sy,2).substr('0'.$sm,-2).substr('0'.$sd,-2).'000000';
				my $end = substr($ey,2).substr('0'.$em,-2).substr('0'.$ed,-2).'235959';
				my $all = $db->selectall_arrayref("SELECT * FROM receiver WHERE count_dt between '$start' and '$end' ORDER BY count_dt DESC ");
				my $r = 1;
			
				foreach my $row (@$all) {
					$worksheet->write_string($r, 0, $device_all{@$row[2]});
					$worksheet->write($r, 1, short_format_t(@$row[4]));
					$worksheet->write_string($r, 2, @$row[2]);
					$worksheet->write($r, 3, short_format_t(@$row[3]));
					$worksheet->write_string($r, 4, @$row[1]);
					$r++;
					
				}
				$status->configure(-text=>'数据导出完毕～～');
				
			})->pack(-side=>'right',-padx=>5,-pady=>2);
		$l_m2->Button(-font=>'宋体 10',-width=>10,-text=>'查询',-command=>sub{
			my $s = $start_dt->get;
			my $e = $end_dt->get;
			$s =~ s/\s+$//g;
			$e =~ s/\s+$//g;
			unless ($s ne ''  && $e ne '') {
					$status->configure(-text=>'请选择查询日期');
					return;
				}
			my ($sy,$sm,$sd) = split('-',$s);
			my ($ey,$em,$ed) = split('-',$e);
			my $start = substr($sy,2).substr('0'.$sm,-2).substr('0'.$sd,-2).'000000';
			my $end = substr($ey,2).substr('0'.$em,-2).substr('0'.$ed,-2).'235959';
			
			my $all = $db->selectall_arrayref("SELECT * FROM receiver WHERE count_dt between '$start' and '$end' ORDER BY count_dt DESC ");
			$data_list->delete('all');
			foreach my $row (@$all) {
			$device_all{@$row[2]} = '' unless(exists $device_all{@$row[2]});
			$data_list->add(@$row[0], -text => $device_all{@$row[2]});
			$data_list->item('create', @$row[0], 1, -text => short_format_t(@$row[4]));
			$data_list->item('create', @$row[0], 2, -text => @$row[2]);
			$data_list->item('create', @$row[0], 3, -text => short_format_t(@$row[3]));
			$data_list->item('create', @$row[0], 4, -text => @$row[1]);
			}
			$status->configure(-text=>'数据查询完毕～～');
				
			})->pack(-side=>'right',-padx=>5,-pady=>2);
		
		
	
	}
	
	
	

}

#显示日期
# sub show_calendar {

	# use Date::Calc qw(:all); 
	# use POSIX qw/strftime/;
	
	# my ($f,$year,$month) = @_;
	# my @maxdays = ( 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );
	# my %days = (
		# "Sun" => 0,
		# "Mon" => 1,
		# "Tue" => 2,
		# "Wed" => 3,
		# "Thu" => 4,
		# "Fri" => 5,
		# "Sat" => 6
	 # );
	 # my @dayArray = ( '星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六' ); # Set the day array
	# my $on = 0;
	# my $ndx = 0;
	# $maxdays[2] = 29 if (leap_year($year));
	# my $a = Date::Calc::Date_to_Text( $year, $month , 01 );
	# my @dateText = split( " ", $a );
	# my $day = $days{$dateText[0]};
	# $f->configure(-text=>"$a");
	
	# for ( my $row = 0; $row < 7 ; $row++ ) {                # create calendar rows
		# for ( my $col = 0 ; $col < 7 ; $col++ ) {    # create calendar columns
			# $b = $f->Button(
				# -width            => 10,              # Create Button
				# -activeforeground => 'white',        # format the foreground
				# -activebackground => 'blue'
			# );                                       # also the background
			# $b->grid( -row => $row, -column => $col); # put this in the right place
			# if ( $row eq 0 ) {                         # if first row,
				# $b->configure(
					# -text  => $dayArray[$col],         # disable the button
					# -state => 'disabled'
				# );
			# }
			# else {
				# if ( $col eq $day && $row eq 1 ) {
					# $on  = 1;
					# $ndx = 1;
				# }    # Turn on switch if start of day
				# if ( int($ndx) > int( $maxdays[$month] ) ) {
					# $on = 0;
				# }    # Turn off switch if all days are displayed
				# if ($on) {
					# $b->configure( -text => $ndx++ );    # put the day on the button

					# and add one to the day
					# $b->bind(
						# "<ButtonPress>",                 # If the button is presssed
						# [ \&DateSelected, $year, $month ]
					# );    # execute the Date Selected subroutine
				# }
				# else {
					# $b->configure( -state => 'disabled' )
					  # ;    # if switch if off, disable button
				# }
			# }
			# if ( $col eq 0 ) {    #if first column, this is Sunday
				# $b->configure(
					# -fg               => 'red',     # configure button
					# -activeforeground => 'white',
					# -activebackground => 'red'
				# );
			# }
		# }
		# if ( int($ndx) > int( $maxdays[$month] ) ) {
			
			  # $b->configure( );
			 # else {
			    # last;
			  # }
		# }    # if all days displayed. exit
	# }
	

# }

# sub DateSelected {    # execute when button is pressed
	# use DBI;
	
	# my $db = DBI->connect("dbi:SQLite:data.db", "", "",{RaiseError => 1, AutoCommit => 1});
	
    # my ( $w, $year, $month ) = @_;    # get the parms (widget, year and month)
    # my $text = $w->cget( -text );                   # get the text on the button
    # print "Date Selected: $text\t$year\t$month\n";  # display information
	# print "Date Selected: $year\t$month\n";
	
	# my $start = substr($year,2).substr('0'.$month,-2).substr('0'.$text,-2).'000000';
	# my $end = substr($year,2).substr('0'.$month,-2).substr('0'.$text,-2).'235959';
	# $data_list->delete('all');
	# my %device_all = map {$_->[2] =>$_->[1]} @{$db->selectall_arrayref("select * from device ")};
	# my $all = $db->selectall_arrayref("SELECT * FROM receiver WHERE RECODER_DT <= '$end' AND RECODER_DT >= '$start' ORDER BY RECODER_DT DESC");
		# foreach my $row (@$all) {
			# $data_list->add(@$row[0], -text => @$row[1]." " x 20);
			# $device_all{@$row[2]} = '' unless(exists $device_all{@$row[2]});
			# $data_list->item('create', @$row[0], 1, -text => $device_all{@$row[2]}." " x 20);
			# $data_list->item('create', @$row[0], 2, -text => @$row[2]." " x 20);
			# $data_list->item('create', @$row[0], 3, -text => format_t(@$row[3])." " x 20);
			# $data_list->item('create', @$row[0], 4, -text => format_t(@$row[4])." " x 20);
		# }
	
# }






 
 #判断表是否存在
 sub table_exists {
    my $db = shift;
    my $table = shift;
    my @tables = $db->tables('','','','TABLE');
    if (@tables) {
        for (@tables) {
            next unless $_;
            return 1 if $_ eq $table
        }
    }
    else {
        eval {
            local $db->{PrintError} = 0;
            local $db->{RaiseError} = 1;
            $db->do(qq{SELECT * FROM $table WHERE 1 = 0 });
        };
        return 1 unless $@;
    }
    return 0;
}


 


sub export_data {
	use Spreadsheet::WriteExcel;  
	
	my ($year,$month);
	
	unless (Exists($export_f)) {
		my $db = DBI->connect("dbi:SQLite:data.db", "", "",{sqlite_unicode => 1, RaiseError => 1, AutoCommit => 1});
		$export_f = $top->Toplevel(-takefocus=>1,-title => '数据导出');
		$export_f->resizable(0,0);
		$export_f->focus;
		my $x = $top->rootx();
		my $y = $top->rooty();
		my $xCoord = $x + 300;
		my $yCoord = $y + 150;
		$export_f->geometry("+$xCoord+$yCoord");
		my $frame1=$export_f->Frame(qw/-borderwidth 2 -relief groove/)->pack(qw/-side top -fill both/);
		my $frame2=$export_f->Frame(qw/-borderwidth 2 -relief groove/)->pack(qw/-side top -fill both/);
		
		my $status = $export_f->Label->pack(qw/-side bottom -expand 1 -fill x /);
		$status->configure(-text=>'请选择导出日期～～',-relief => 'groove', -background => '#FFFF99',-font=>'宋体 10');
		my $device_all = $db->selectall_arrayref("SELECT * FROM device ORDER BY id");
		my %device_counter = map {$_->[4]=>$_->[2]} @$device_all;
		my $device;
		
		$frame1->BrowseEntry(-relief => 'groove',-font=>'宋体 10',-label => '请选择要导出的防雷点: ', -variable => \$device, -choices => [keys %device_counter] )->pack(qw/-side left -padx 5 -pady 10/);
		$frame2->Button(-font=>'宋体 10',-width=>10,-text=>'关闭',-command=>sub{
				$export_f->destroy;
			})->pack(-side=>'right',-padx=>5,-pady=>2);
		$frame2->Button(-font=>'宋体 10',-width=>10,-text=>'导出',-command=>sub{
				
				unless($device) {
					$status->configure(-text=>'没有选择设备号～～');
					return;
				}
		
				my $file = $export_f->getSaveFile(-title=>'导出文件',-defaultextension => '.xls'); 
				return unless $file;

				my $ansi_path = Win32::GetANSIPathName($file);
				
				my $workbook = Spreadsheet::WriteExcel->new($ansi_path); 
				my $worksheet = $workbook->add_worksheet();  
				my $format = $workbook->add_format();
				my $bold = $workbook->add_format(bold => 1);
				$worksheet->set_row(0, 20, $bold);
				$worksheet->set_column('D:E', 30);
				  
			
				my @headings = ('防雷点名称','雷击时间','计数器编号','抄录时间','读写器编号');
				$worksheet->write('A1', \@headings);
				
				my $all = $db->selectall_arrayref("select * from receiver WHERE count_s = '$device_counter{$device}' ");
				my $r = 1;
				my %counter_device = reverse %device_counter;
				foreach my $row (@$all) {
					
					$worksheet->write_string($r, 0, $counter_device{@$row[2]});
					$worksheet->write($r, 1, short_format_t(@$row[4]));
					$worksheet->write_string($r, 2, @$row[2]);
					$worksheet->write($r, 3, short_format_t(@$row[3]));
					$worksheet->write_string($r, 4, @$row[1]);
					$r++;
					
				}
				  
				
				$status->configure(-text=>'数据导出完毕～～');
				$export_f->bell;
				})->pack(-side=>'right',-padx=>5,-pady=>2);
	    
		
	}else {
		$export_f->deiconify( );
		$export_f->raise( );
	}
}

