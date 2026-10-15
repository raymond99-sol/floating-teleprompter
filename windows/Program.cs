using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;

namespace FloatingTeleprompter;

public sealed class Settings
{
    public string Script { get; set; } = "Paste your script here.\n\nSpeak naturally and let the words move toward the camera.\n\n在这里粘贴或编辑中文、英文台词。可调整开头留白、速度与透明度。";
    public double Speed { get; set; } = 140;
    public double Gap { get; set; } = 80;
    public double Opacity { get; set; } = .94;
}

public sealed class PrompterWindow : Window
{
    readonly bool smoke;
    readonly Settings settings;
    readonly string settingsFile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "FloatingTeleprompter", "settings.json");
    readonly TextBox editor = new();
    readonly TextBlock text = new();
    readonly ScrollViewer reader = new();
    readonly Border leading = new();
    readonly Border trailing = new();
    readonly Button play = new() { Content = "开始" };
    readonly Slider speed = new() { Minimum = 60, Maximum = 240, Value = 140 };
    readonly Slider gap = new() { Minimum = 0, Maximum = 400, Value = 80 };
    readonly Stopwatch clock = Stopwatch.StartNew();
    double last, position;
    bool running, finished;

    public PrompterWindow(bool smokeTest)
    {
        smoke = smokeTest;
        settings = new Settings();
        if (!smoke)
        {
            try { if (File.Exists(settingsFile)) settings = JsonSerializer.Deserialize<Settings>(File.ReadAllText(settingsFile)) ?? settings; }
            catch (Exception e) when (e is IOException or JsonException or UnauthorizedAccessException) { }
        }
        Title = "悬浮提词器"; Width = 560; Height = 430; MinWidth = 460; MinHeight = 310;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Background = new SolidColorBrush(Color.FromRgb(18, 18, 18)); Foreground = Brushes.White;
        Topmost = true; Opacity = Math.Clamp(settings.Opacity, .45, 1);
        var root = new DockPanel { Margin = new Thickness(12) };
        Content = root;
        var toolbar = new StackPanel(); DockPanel.SetDock(toolbar, Dock.Top); root.Children.Add(toolbar);
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 8) };
        toolbar.Children.Add(buttons);
        play.Click += (_, _) => Toggle(); buttons.Children.Add(play);
        var reset = new Button { Content = "重置" }; reset.Click += (_, _) => Reset(); buttons.Children.Add(reset);
        var edit = new Button { Content = "编辑台词" }; edit.Click += (_, _) => Edit(); buttons.Children.Add(edit);
        foreach (Button b in buttons.Children) { b.Padding = new Thickness(9, 4, 9, 4); b.Margin = new Thickness(0, 0, 7, 0); }
        var top = new CheckBox { Content = "置顶", IsChecked = true, VerticalAlignment = VerticalAlignment.Center, Foreground = Brushes.White };
        top.Checked += (_, _) => Topmost = true; top.Unchecked += (_, _) => Topmost = false; buttons.Children.Add(top);
        speed.Value = Math.Clamp(settings.Speed, 60, 240); gap.Value = Math.Clamp(settings.Gap, 0, 400);
        AddSlider(toolbar, speed, "词/分钟", () => settings.Speed = speed.Value);
        AddSlider(toolbar, gap, "开头留白", () => { settings.Gap = gap.Value; Reset(); });
        var opacity = new Slider { Minimum = .45, Maximum = 1, Value = Opacity };
        AddSlider(toolbar, opacity, "透明度 %", () => { Opacity = opacity.Value; settings.Opacity = opacity.Value; }, 100);
        toolbar.Children.Add(new TextBlock { Text = "粘贴中英文台词 · 拖动标题栏移动 · 拖动边缘缩放", FontSize = 11, Foreground = Brushes.LightGray, Margin = new Thickness(0, 0, 0, 8) });
        var body = new Grid(); root.Children.Add(body);
        editor.Text = settings.Script; editor.AcceptsReturn = true; editor.AcceptsTab = true;
        editor.TextWrapping = TextWrapping.Wrap; editor.VerticalScrollBarVisibility = ScrollBarVisibility.Auto;
        editor.Background = Brushes.Transparent; editor.Foreground = Brushes.White; editor.CaretBrush = Brushes.White;
        editor.BorderThickness = new Thickness(0); editor.Padding = new Thickness(20, 10, 20, 10);
        editor.FontFamily = new FontFamily("Segoe UI"); editor.FontSize = 30;
        editor.TextChanged += (_, _) => { settings.Script = editor.Text; Save(); };
        body.Children.Add(editor);
        var page = new StackPanel();
        text.FontSize = 30; text.FontFamily = editor.FontFamily; text.Foreground = Brushes.White;
        text.TextWrapping = TextWrapping.Wrap; text.LineHeight = 46; text.Margin = new Thickness(20, 0, 20, 0);
        page.Children.Add(leading); page.Children.Add(text); page.Children.Add(trailing);
        reader.Content = page; reader.CanContentScroll = false;
        reader.HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled;
        reader.VerticalScrollBarVisibility = ScrollBarVisibility.Hidden;
        reader.Visibility = Visibility.Collapsed; body.Children.Add(reader);
        reader.SizeChanged += (_, _) => { trailing.Height = Math.Max(1, reader.ActualHeight); };
        Closing += (_, _) => Save();
        CompositionTarget.Rendering += Render;
        Closed += (_, _) => CompositionTarget.Rendering -= Render;
    }

    void AddSlider(Panel parent, Slider slider, string label, Action changed, double multiplier = 1)
    {
        var row = new DockPanel { Margin = new Thickness(0, 0, 0, 6) };
        var caption = new TextBlock { Width = 125, VerticalAlignment = VerticalAlignment.Center, TextAlignment = TextAlignment.Right };
        void Update() => caption.Text = $"{label} {slider.Value * multiplier:0}";
        Update(); DockPanel.SetDock(caption, Dock.Right); row.Children.Add(caption); row.Children.Add(slider); parent.Children.Add(row);
        slider.ValueChanged += (_, _) => { Update(); changed(); Save(); };
    }
    void Save()
    {
        if (smoke) return;
        try { Directory.CreateDirectory(Path.GetDirectoryName(settingsFile)!); File.WriteAllText(settingsFile, JsonSerializer.Serialize(settings)); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
    }
    void Prepare()
    {
        text.Text = editor.Text;
        leading.Height = 22 + gap.Value;
        editor.Visibility = Visibility.Collapsed; reader.Visibility = Visibility.Visible;
        UpdateLayout(); trailing.Height = Math.Max(1, reader.ActualHeight); UpdateLayout();
    }
    void Toggle()
    {
        if (finished) Reset();
        if (reader.Visibility != Visibility.Visible) Prepare();
        running = !running; play.Content = running ? "暂停" : "开始";
        position = reader.VerticalOffset; last = clock.Elapsed.TotalSeconds;
    }
    void Reset()
    {
        running = false; finished = false; play.Content = "开始"; position = 0;
        if (reader.Visibility == Visibility.Visible) { leading.Height = 22 + gap.Value; reader.ScrollToVerticalOffset(0); }
    }
    void Edit()
    {
        Reset(); reader.Visibility = Visibility.Collapsed; editor.Visibility = Visibility.Visible; editor.Focus();
    }
    public static double Units(string script) => Math.Max(1, Regex.Matches(script, @"[A-Za-z0-9]+(?:['’][A-Za-z0-9]+)*").Count + Regex.Matches(script, @"[\u3400-\u9fff]").Count * 140.0 / 300.0);
    void Render(object? sender, EventArgs e)
    {
        double now = clock.Elapsed.TotalSeconds;
        double elapsed = Math.Clamp(now - last, 0, .1); last = now;
        if (running) Step(elapsed);
    }
    void Step(double elapsed)
    {
        double pixelsPerSecond = Math.Max(text.ActualHeight, 46) / Units(text.Text) * speed.Value / 60;
        position = Math.Min(position + elapsed * pixelsPerSecond, reader.ScrollableHeight);
        reader.ScrollToVerticalOffset(position);
        if (position >= reader.ScrollableHeight) { running = false; finished = true; play.Content = "开始"; }
    }
    public void SmokeTest()
    {
        void Check(bool ok, string message) { if (!ok) throw new InvalidOperationException(message); }
        editor.Text = "One two three four five.\n中文测试。";
        gap.Value = 120; Prepare(); Toggle();
        Check(running && Topmost, "Start / always-on-top");
        Check(leading.ActualHeight == 142, "Configurable leading whitespace");
        Step(1); UpdateLayout();
        Check(position > 0 && reader.VerticalOffset > 0, "Continuous scrolling including leading whitespace");
        Toggle(); double paused = position; Render(null, EventArgs.Empty);
        Check(!running && position == paused, "Pause");
        Toggle(); Step(10000); UpdateLayout();
        Check(finished && !running, "Stop after last line leaves");
        Check(reader.VerticalOffset >= leading.ActualHeight + text.ActualHeight - 1, "Final line completely above viewport");
        Reset(); UpdateLayout(); Check(reader.VerticalOffset == 0, "Reset");
        Edit(); Check(editor.Visibility == Visibility.Visible, "Editor");
        Check(Math.Abs(Units("hello world 中文") - (2 + 2 * 140.0 / 300)) < .001, "Mixed-language speed");
    }
}

public static class Program
{
    [STAThread]
    public static int Main(string[] args)
    {
        bool smoke = args.Contains("--smoke-test");
        var app = new Application();
        var window = new PrompterWindow(smoke);
        int result = 0;
        if (smoke) window.Loaded += (_, _) => window.Dispatcher.BeginInvoke(DispatcherPriority.ApplicationIdle, new Action(() =>
        {
            try { window.SmokeTest(); }
            catch (Exception e) { File.WriteAllText("smoke-test-error.txt", e.ToString()); result = 1; }
            app.Shutdown(result);
        }));
        return app.Run(window);
    }
}
