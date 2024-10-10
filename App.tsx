import { StatusBar } from "expo-status-bar";
import { useCallback, useState } from "react";
import { StyleSheet, Text, TouchableWithoutFeedback, View } from "react-native";

export default function App() {
  const [textColor, setTextColor] = useState("#000");

  const randomColor = useCallback(() => {
    const letters = "0123456789ABCDEF";
    let color = "#";

    for (let i = 0; i < 6; i++) {
      color += letters[Math.floor(Math.random() * 16)];
    }

    setTextColor(color);
  }, []);

  return (
    <TouchableWithoutFeedback onPress={randomColor}>
      <View style={styles.container}>
        <Text selectable={false} style={{ color: textColor }}>Hello there</Text>
        <StatusBar style="auto" />
      </View>
    </TouchableWithoutFeedback>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
  },
});
