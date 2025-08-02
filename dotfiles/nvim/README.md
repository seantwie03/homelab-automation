# Neovim

## TODO
- Fix checkhealth telescope
- Indent Guides and Rainbow Delimiters
    - https://github.com/lukas-reineke/indent-blankline.nvim
    - https://gitlab.com/HiPhish/rainbow-delimiters.nvim
- Yazi to replace Oil
    - https://github.com/mikavilpas/yazi.nvim
    - https://github.com/sxyazi/yazi
- Diff Viewer
    - https://www.lazyvim.org/extras/editor/mini-diff

## Blogs

- Workflow for Command Line Demonstrations
    - I think this is already written in my Reddit comments
- Achieving RHCSA
    - RHEL_LAB project
- Ansible 101 LUG talk
- Ansible Pull LUG talk


# Reflections on My First Time Teaching

In Spring 2025 I was fortunate enough to be able to teach the Linux Administration course at the [St. Charles Community College (SCC)](https://www.stchas.edu/). SCC is a [Red Hat Academy](https://www.redhat.com/en/services/training/red-hat-academy) Institution and uses the Red Hat Academy curriculum for it's Linux courses.

The Linux Administration course I taught is the most advanced Linux course that SCC offers. It prepares students for the [Red Hat Certified Systems Administrator (RHCSA)](https://www.redhat.com/en/services/certification/rhcsa) and [Red Hat Certified Engineer (RHCE)](https://www.redhat.com/en/services/training/ex294-red-hat-certified-engineer-rhce-exam-red-hat-enterprise-linux-9) certification exams. (Red Hat Academy courses: [RH-134](https://www.redhat.com/en/services/training/rh134-red-hat-system-administration-ii) and [RH-294](https://www.redhat.com/en/services/training/rh294-red-hat-linux-automation-with-ansible).)

I had a blast teaching this course, but it did take me a couple classes to really hit my stride. By week 3 I had settled on using the [I do, We Do, You Do](https://classwork.com/i-do-we-do-you-do-strategy-gradual-release-strategy/) strategy. Here is an outline of my application of the strategy.

I start off with a short slideshow presentation. The main goal with this presentation is to motivate the students. In approximately 5-slides (or less) I try to explain what they will learn and why it is worth learning.

Next, we move into the 'I do' portion. In the last slide of the presentation I will I give myself a task like: "Mount an NFS share persistently." Then I will give a hands-on demonstration where I accomplish the task. I make sure to go very slow and explain everything I am doing. Ideally this hands-on demonstration will be as long or longer than the slideshow presentation.

Then, I give the students 10 minutes to walk through the Guided Exercises in the Red Hat Academy. Each student is doing this on their own, but we are all doing it at the same time. This is the 'We do' portion where students engage in effortful practice. I encourage students to ask questions and seek help if they get stuck. Ideally this portion would not be graded; however, I found some students were not participating so I had to make this a graded activity.

After class, students must complete the Red Hat Academy Labs as homework. This is the 'You do' portion.

The task in each section similar, but not identical. I think of this sort of like an algebra class where my in-class demo (I do), the guided exercise (we do), the lab (you do), and the RHCSA exam all use the same "formula", but each problem has slight variations.

I can usually get through 4 of these iterations per class. Here are some benefits I've seen with this approach:

    Constant change keeps students engaged. The students do not have to listen to a long lecture. Instead we do a short presentation, short demonstration, and a short bout of effortful practice.

    Bite-sized chunks. The students watch a short hands-on demonstration then immediately put their hands on the keyboard to practice. In my opinion this is more manageable than watching a 2+ hour lecture then trying to remember everything when you get home to do the lab.

I usually try to save 10 minutes at the end of class for a conversation. I've worked in the industry for 17 years. I want to try to share my experience with the students, but experience is hard to transfer, so I am hoping that by having a short conversation at the end of each class the students will ask questions that will pull stories out of me. Here are some examples of the conversation topics I've brought to these end of class discussions:

    Knowledge Work - We in IT are knowledge workers. We get paid an above average salary because of the things we know. The more you know the more capable (and valuable) you are.

    Continuous Learning is required to be in the IT Industry. Each "IT Field" has an ecosystem. You will need to spend time on your own learning the "ecosystem" surrounding your field. This is a Linux class, so I gave examples of Linux ecosystems (Red Hat, CentOS, Fedora, Open Shift vs Debian, Ubuntu, K8s, etc.)

    Technical Interview Tip: Listen to podcasts related to your field. What happens in a technical interview? You must talk conversationally about deeply technical concepts. What happens on a good IT podcast? Two or more experienced hosts talk conversationally about deeply technical concepts. Also, podcasts are a great way to learn about your field's ecosystem.

All in all, I had a great time teaching Linux Administration and have a strong desire to continue teaching. One area I will strive to improve is the use of visual aids. I used a LOT of color and pictures in my slides but they were mostly just decorative. The Linux command line interface (cli) can be a very monochrome text-heavy place. Using lots of color and decorative images in my slides brought a lot of variety, but with better use of visual aids I could include pictures, charts, and graphs that are both colorful and informative.
