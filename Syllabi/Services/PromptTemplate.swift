import Foundation

public struct PromptTemplate {
    public static let aiFormatterPrompt = """
You are an expert academic curriculum assistant. Please convert the provided course syllabus or topic list into a standardized Markdown format optimized for the Syllabi tracker app.

Strict Formatting Rules:
1. Include a YAML frontmatter block at the top with:
   - `subject`: The full course name
   - `code`: The course code (e.g., CS101, MATH204), or empty if none
   - `term`: Semester or term (e.g., "Fall 2024", "Sem 5")
   - `icon`: An Apple SF Symbol name (e.g., book.closed.fill, laptopcomputer, ruler.fill, atom, cpu.fill, brain.head.profile, chart.bar.fill, paintbrush.fill, terminal.fill). Do NOT use emojis!
   - `color`: A vibrant hex color code (e.g., "#3652FD", "#10B981", "#8B5CF6", "#F59E0B", "#EF4444")

2. Structure Units as H2 headings (`## `):
   - Example: `## Unit 1: Foundations of Computer Science`

3. Format Topics as Markdown task list items:
   - Example: `- [ ] Introduction to Algorithms [High] [Core]`
   - Mark completed items as `- [x] ` if already finished.
   - Add inline bracketed tags at the end of the line (e.g., `[High]`, `[Exam]`, `[Review]`, `[Lab]`).

4. Format Subtopics indented with 2 spaces under their parent topic:
   - Example:
     ```markdown
     - [ ] Data Structures [Core]
       - [ ] Singly and Doubly Linked Lists
       - [ ] Binary Search Trees [Exam]
       - [ ] Hash Tables with Chaining
     ```

5. Include Study Notes or key concepts as blockquotes (`> `) immediately following the topic or subtopic:
   - Example:
     ```markdown
     - [ ] Dynamic Programming [High] [Exam]
       > Focus on tabulation vs memoization and overlapping subproblems.
     ```

Please convert the following syllabus into this exact format:

[PASTE YOUR SYLLABUS TEXT HERE]
"""
}
