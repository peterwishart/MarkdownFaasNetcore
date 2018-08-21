using System;
using System.Text;

namespace Function
{
    public class FunctionHandler
    {
        public void Handle(string input) {
            var asString = Markdig.Markdown.ToHtml(input);
            Console.WriteLine(asString);
        }
    }
}
