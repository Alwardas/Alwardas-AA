with open('debug_subjects_output.txt', 'rb') as f:
    content = f.read()
    try:
        print(content.decode('utf-16'))
    except:
        print(content.decode('utf-8'))
